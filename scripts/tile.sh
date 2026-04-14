#!/usr/bin/env bash

# Get full desktop dimensions
FULL_WIDTH=$(xdpyinfo | grep dimensions | awk '{print $2}' | cut -d'x' -f1)
FULL_HEIGHT=$(xdpyinfo | grep dimensions | awk '{print $2}' | cut -d'x' -f2)

# Calculate halves and quarters
HALF_WIDTH=$((FULL_WIDTH / 2))
QUARTER_WIDTH=$((FULL_WIDTH / 4))
QUARTER_HEIGHT=$((FULL_HEIGHT / 4))

usage() {
    echo "Usage: tile.sh [command]"
    echo ""
    echo "Commands:"
    echo "  left          Fill entire left monitor"
    echo "  right         Fill entire right monitor"
    echo "  auto          Fill whichever monitor the window is currently on"
    echo "  center        Resize to 1/4 monitor size and center on current monitor"
    echo "  quarter [1-6] Fill a quarter of the desktop"
    echo "                  1 = left monitor,  left side"
    echo "                  2 = left monitor,  right side"
    echo "                  3 = right monitor, left side"
    echo "                  4 = right monitor, right side"
    echo "                  5 = auto, left side of current monitor"
    echo "                  6 = auto, right side of current monitor"
    exit 1
}

get_window_x() {
    WINDOW_ID=$(xdotool getactivewindow)
    xdotool getwindowgeometry $WINDOW_ID | grep Position | awk '{print $2}' | cut -d',' -f1
}

get_current_monitor() {
    WINDOW_X=$(get_window_x)
    if [ "$WINDOW_X" -lt "$HALF_WIDTH" ]; then
        echo "left"
    else
        echo "right"
    fi
}

tile_left() {
    wmctrl -r :ACTIVE: -e 0,0,0,$HALF_WIDTH,$FULL_HEIGHT
}

tile_right() {
    wmctrl -r :ACTIVE: -e 0,$HALF_WIDTH,0,$HALF_WIDTH,$FULL_HEIGHT
}

tile_auto() {
    if [ "$(get_current_monitor)" = "left" ]; then
        tile_left
    else
        tile_right
    fi
}

tile_center() {
    # Window will be 1/4 of monitor dimensions
    WIN_WIDTH=$((HALF_WIDTH / 2))
    WIN_HEIGHT=$((FULL_HEIGHT / 2))

    if [ "$(get_current_monitor)" = "left" ]; then
        # Center on left monitor
        MONITOR_OFFSET=0
    else
        # Center on right monitor
        MONITOR_OFFSET=$HALF_WIDTH
    fi

    # Calculate centered position within the monitor
    POS_X=$((MONITOR_OFFSET + (HALF_WIDTH / 2) - (WIN_WIDTH / 2)))
    POS_Y=$(((FULL_HEIGHT / 2) - (WIN_HEIGHT / 2)))

    wmctrl -r :ACTIVE: -e 0,$POS_X,$POS_Y,$WIN_WIDTH,$WIN_HEIGHT
}

tile_quarter() {
    case $1 in
        1) wmctrl -r :ACTIVE: -e 0,0,0,$QUARTER_WIDTH,$FULL_HEIGHT ;;
        2) wmctrl -r :ACTIVE: -e 0,$QUARTER_WIDTH,0,$QUARTER_WIDTH,$FULL_HEIGHT ;;
        3) wmctrl -r :ACTIVE: -e 0,$HALF_WIDTH,0,$QUARTER_WIDTH,$FULL_HEIGHT ;;
        4) wmctrl -r :ACTIVE: -e 0,$((HALF_WIDTH + QUARTER_WIDTH)),0,$QUARTER_WIDTH,$FULL_HEIGHT ;;
        5)
            if [ "$(get_current_monitor)" = "left" ]; then
                wmctrl -r :ACTIVE: -e 0,0,0,$QUARTER_WIDTH,$FULL_HEIGHT
            else
                wmctrl -r :ACTIVE: -e 0,$HALF_WIDTH,0,$QUARTER_WIDTH,$FULL_HEIGHT
            fi
            ;;
        6)
            if [ "$(get_current_monitor)" = "left" ]; then
                wmctrl -r :ACTIVE: -e 0,$QUARTER_WIDTH,0,$QUARTER_WIDTH,$FULL_HEIGHT
            else
                wmctrl -r :ACTIVE: -e 0,$((HALF_WIDTH + QUARTER_WIDTH)),0,$QUARTER_WIDTH,$FULL_HEIGHT
            fi
            ;;
        *) echo "Error: quarter requires argument 1-6"; usage ;;
    esac
}

# Main
case $1 in
    left)    tile_left ;;
    right)   tile_right ;;
    auto)    tile_auto ;;
    center)  tile_center ;;
    quarter) tile_quarter $2 ;;
    *)       usage ;;
esac