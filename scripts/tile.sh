#!/usr/bin/env bash

#
# Dependencies
#

for cmd in xrandr xdpyinfo xdotool wmctrl xprop awk; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Error: required command '$cmd' not found" >&2
        exit 1
    }
done

#
# Desktop geometry
#

read -r FULL_WIDTH FULL_HEIGHT < <(
    xdpyinfo | awk '
        /dimensions:/ {
            split($2, a, "x")
            print a[1], a[2]
            exit
        }
    '
)

if [[ -z "$FULL_WIDTH" || -z "$FULL_HEIGHT" ]]; then
    echo "Error: unable to determine desktop dimensions" >&2
    exit 1
fi

HALF_WIDTH=$((FULL_WIDTH / 2))

#
# Monitor data
#

declare -a MON_NAME
declare -a MON_X
declare -a MON_Y
declare -a MON_W
declare -a MON_H

MON_COUNT=0
LEFT_MON=0
RIGHT_MON=0

#
# Usage
#

usage() {
    echo "Usage: tile.sh [command]"
    echo ""
    echo "Commands:"
    echo "  left          Fill entire left monitor"
    echo "  right         Fill entire right monitor"
    echo "  auto          Fill whichever monitor the window is currently on"
    echo "  center        Resize to 1/4 monitor area and center on current monitor"
    echo "  quarter [1-6] Fill one half of a monitor"
    echo "                  landscape: left/right"
    echo "                  portrait:  top/bottom"
    echo ""
    echo "                  1 = left monitor,  first half"
    echo "                  2 = left monitor,  second half"
    echo "                  3 = right monitor, first half"
    echo "                  4 = right monitor, second half"
    echo "                  5 = current monitor, first half"
    echo "                  6 = current monitor, second half"
    echo ""
    echo "  debug         Show detected monitor geometry and current monitor"
    exit 1
}

#
# Monitor detection
#

load_randr_monitors() {
    local name geom

    while read -r name geom; do
        if [[ "$geom" =~ ^([0-9]+)x([0-9]+)([+-][0-9]+)([+-][0-9]+)$ ]]; then
            MON_NAME[MON_COUNT]="$name"
            MON_W[MON_COUNT]="${BASH_REMATCH[1]}"
            MON_H[MON_COUNT]="${BASH_REMATCH[2]}"
            MON_X[MON_COUNT]="${BASH_REMATCH[3]}"
            MON_Y[MON_COUNT]="${BASH_REMATCH[4]}"
            ((MON_COUNT++))
        fi
    done < <(
        xrandr --query | awk '
            $2 == "connected" {
                for (i = 3; i <= NF; i++) {
                    if ($i ~ /^[0-9]+x[0-9]+[+-][0-9]+[+-][0-9]+$/) {
                        print $1, $i
                        break
                    }
                }
            }
        '
    )
}

load_legacy_monitors() {
    # Original Xinerama behavior:
    # treat the desktop as two equally-sized monitors arranged horizontally.
    MON_COUNT=2

    MON_NAME[0]="legacy-left"
    MON_X[0]=0
    MON_Y[0]=0
    MON_W[0]=$HALF_WIDTH
    MON_H[0]=$FULL_HEIGHT

    MON_NAME[1]="legacy-right"
    MON_X[1]=$HALF_WIDTH
    MON_Y[1]=0
    MON_W[1]=$HALF_WIDTH
    MON_H[1]=$FULL_HEIGHT
}

find_edge_monitors() {
    local i

    LEFT_MON=0
    RIGHT_MON=0

    for ((i = 1; i < MON_COUNT; i++)); do
        if (( MON_X[i] < MON_X[LEFT_MON] )); then
            LEFT_MON=$i
        fi

        if (( MON_X[i] > MON_X[RIGHT_MON] )); then
            RIGHT_MON=$i
        fi
    done
}

load_monitors() {
    load_randr_monitors

    # Some Xinerama setups expose only one large RandR screen rather than
    # individual physical monitors. Preserve the original two-monitor
    # behavior in that case.
    if (( MON_COUNT < 2 )); then
        MON_NAME=()
        MON_X=()
        MON_Y=()
        MON_W=()
        MON_H=()

        load_legacy_monitors
    fi

    find_edge_monitors
}

#
# Active window geometry
#

get_window_geometry() {
    local key value

    WINDOW_ID=$(xdotool getactivewindow)

    while IFS='=' read -r key value; do
        case "$key" in
            X)      WIN_X=$value ;;
            Y)      WIN_Y=$value ;;
            WIDTH)  WIN_W=$value ;;
            HEIGHT) WIN_H=$value ;;
        esac
    done < <(
        xdotool getwindowgeometry --shell "$WINDOW_ID"
    )
}

#
# Determine which monitor contains most of the active window.
#

get_current_monitor() {
    get_window_geometry

    local i
    local mx my mw mh
    local wx2 wy2 mx2 my2
    local overlap_left
    local overlap_top
    local overlap_right
    local overlap_bottom
    local overlap_w
    local overlap_h
    local area

    local best_monitor=-1
    local best_area=-1

    wx2=$((WIN_X + WIN_W))
    wy2=$((WIN_Y + WIN_H))

    for ((i = 0; i < MON_COUNT; i++)); do
        mx=${MON_X[i]}
        my=${MON_Y[i]}
        mw=${MON_W[i]}
        mh=${MON_H[i]}

        mx2=$((mx + mw))
        my2=$((my + mh))

        if (( WIN_X > mx )); then
            overlap_left=$WIN_X
        else
            overlap_left=$mx
        fi

        if (( WIN_Y > my )); then
            overlap_top=$WIN_Y
        else
            overlap_top=$my
        fi

        if (( wx2 < mx2 )); then
            overlap_right=$wx2
        else
            overlap_right=$mx2
        fi

        if (( wy2 < my2 )); then
            overlap_bottom=$wy2
        else
            overlap_bottom=$my2
        fi

        overlap_w=$((overlap_right - overlap_left))
        overlap_h=$((overlap_bottom - overlap_top))

        if (( overlap_w > 0 && overlap_h > 0 )); then
            area=$((overlap_w * overlap_h))

            if (( area > best_area )); then
                best_area=$area
                best_monitor=$i
            fi
        fi
    done

    if (( best_monitor >= 0 )); then
        echo "$best_monitor"
        return
    fi

    # If the window somehow falls outside every monitor, use whichever
    # monitor center is closest to the window center.
    local win_cx=$((WIN_X + WIN_W / 2))
    local win_cy=$((WIN_Y + WIN_H / 2))
    local mon_cx
    local mon_cy
    local dx
    local dy
    local distance
    local best_distance=-1

    for ((i = 0; i < MON_COUNT; i++)); do
        mon_cx=$((MON_X[i] + MON_W[i] / 2))
        mon_cy=$((MON_Y[i] + MON_H[i] / 2))

        dx=$((win_cx - mon_cx))
        dy=$((win_cy - mon_cy))
        distance=$((dx * dx + dy * dy))

        if (( best_distance < 0 || distance < best_distance )); then
            best_distance=$distance
            best_monitor=$i
        fi
    done

    echo "$best_monitor"
}

#
# Window decorations
#

get_height() {
    local target_height=$1
    local window_id
    local decoration=0
    local calculated_height

    window_id=$(xdotool getactivewindow)

    decoration=$(
        xprop -id "$window_id" _NET_FRAME_EXTENTS 2>/dev/null |
            awk -F'= ' '
                NF == 2 {
                    gsub(/,/, "", $2)
                    split($2, e, /[[:space:]]+/)

                    # _NET_FRAME_EXTENTS is:
                    # left, right, top, bottom
                    print e[3] + e[4]
                }
            '
    )

    decoration=${decoration:-0}
    calculated_height=$((target_height - decoration))

    # Protect against bogus frame-extents data.
    if (( calculated_height < 1 )); then
        calculated_height=$target_height
    fi

    echo "$calculated_height"
}

#
# Window movement
#

move_window() {
    local x=$1
    local y=$2
    local w=$3
    local h=$4

    # Maximized windows can cause some WMs to ignore geometry requests.
    wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz

    wmctrl -r :ACTIVE: -e "0,$x,$y,$w,$h"
}

#
# Fill one entire monitor
#

tile_monitor() {
    local monitor=$1

    local x=${MON_X[monitor]}
    local y=${MON_Y[monitor]}
    local w=${MON_W[monitor]}
    local h

    h=$(get_height "${MON_H[monitor]}")

    move_window "$x" "$y" "$w" "$h"
}

#
# Fill one half of a monitor.
#
# Landscape:
#   first  = left
#   second = right
#
# Portrait:
#   first  = top
#   second = bottom
#

tile_monitor_half() {
    local monitor=$1
    local side=$2

    local x=${MON_X[monitor]}
    local y=${MON_Y[monitor]}
    local monitor_width=${MON_W[monitor]}
    local monitor_height=${MON_H[monitor]}

    local w
    local target_height
    local h

    if (( monitor_height > monitor_width )); then
        #
        # Portrait monitor
        #

        local half_height=$((monitor_height / 2))

        w=$monitor_width

        case "$side" in
            first)
                # Top half
                target_height=$half_height
                ;;
            second)
                # Bottom half
                y=$((y + half_height))
                target_height=$((monitor_height - half_height))
                ;;
            *)
                echo "Error: invalid half '$side'" >&2
                exit 1
                ;;
        esac
    else
        #
        # Landscape monitor
        #

        local half_width=$((monitor_width / 2))

        target_height=$monitor_height

        case "$side" in
            first)
                # Left half
                w=$half_width
                ;;
            second)
                # Right half
                x=$((x + half_width))
                w=$((monitor_width - half_width))
                ;;
            *)
                echo "Error: invalid half '$side'" >&2
                exit 1
                ;;
        esac
    fi

    # Adjust the vertical client size once, after the desired rectangle
    # has been fully calculated.
    h=$(get_height "$target_height")

    move_window "$x" "$y" "$w" "$h"
}

#
# Public commands
#

tile_left() {
    tile_monitor "$LEFT_MON"
}

tile_right() {
    tile_monitor "$RIGHT_MON"
}

tile_auto() {
    local monitor

    monitor=$(get_current_monitor)

    tile_monitor "$monitor"
}

tile_center() {
    local monitor

    monitor=$(get_current_monitor)

    local mx=${MON_X[monitor]}
    local my=${MON_Y[monitor]}
    local mw=${MON_W[monitor]}
    local mh=${MON_H[monitor]}

    # Half width x half height = one quarter of the monitor's area.
    local win_width=$((mw / 2))
    local target_height=$((mh / 2))
    local win_height

    local pos_x=$((mx + (mw - win_width) / 2))
    local pos_y=$((my + (mh - target_height) / 2))

    win_height=$(get_height "$target_height")

    move_window "$pos_x" "$pos_y" "$win_width" "$win_height"
}

tile_quarter() {
    case "$1" in
        1)
            tile_monitor_half "$LEFT_MON" first
            ;;
        2)
            tile_monitor_half "$LEFT_MON" second
            ;;
        3)
            tile_monitor_half "$RIGHT_MON" first
            ;;
        4)
            tile_monitor_half "$RIGHT_MON" second
            ;;
        5)
            tile_monitor_half "$(get_current_monitor)" first
            ;;
        6)
            tile_monitor_half "$(get_current_monitor)" second
            ;;
        *)
            echo "Error: quarter requires argument 1-6" >&2
            usage
            ;;
    esac
}

#
# Debugging
#

debug_monitors() {
    local i
    local current

    current=$(get_current_monitor)

    echo "Desktop: ${FULL_WIDTH}x${FULL_HEIGHT}"
    echo
    echo "Detected monitors:"

    for ((i = 0; i < MON_COUNT; i++)); do
        printf '  %d: %-16s %dx%d%+d%+d' \
            "$i" \
            "${MON_NAME[i]}" \
            "${MON_W[i]}" \
            "${MON_H[i]}" \
            "${MON_X[i]}" \
            "${MON_Y[i]}"

        if (( MON_H[i] > MON_W[i] )); then
            printf '  portrait'
        else
            printf '  landscape'
        fi

        if (( i == current )); then
            printf '  [current]'
        fi

        echo
    done

    echo
    echo "Left monitor:  ${MON_NAME[LEFT_MON]}"
    echo "Right monitor: ${MON_NAME[RIGHT_MON]}"
    echo "Current:       ${MON_NAME[current]}"
}

#
# Main
#

load_monitors

case "${1:-}" in
    left)
        tile_left
        ;;

    right)
        tile_right
        ;;

    auto)
        tile_auto
        ;;

    center)
        tile_center
        ;;

    quarter)
        tile_quarter "${2:-}"
        ;;

    debug)
        debug_monitors
        ;;

    *)
        usage
        ;;
esac
