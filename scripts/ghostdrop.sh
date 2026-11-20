#!/usr/bin/env bash
# Toggle a drop-down Ghostty window (via tdrop) attached to a persistent
# tmux session. If any piece is missing, fall back gracefully:
#   - no tmux            -> drop-down Ghostty without tmux
#   - no tdrop/ghostty,
#     not on X11, or
#     tdrop fails        -> the system's default terminal in a normal window

SESSION="dropdown"
WIDTH="100%"
HEIGHT="45%"

have() { command -v "$1" >/dev/null 2>&1; }

complain() {
    if have notify-send; then
        notify-send "dropdown-terminal" "$1"
    else
        echo "dropdown-terminal: $1" >&2
    fi
}

open_default_terminal() {
    # User's explicit choice wins (may include arguments, so left unquoted)
    if [[ -n "${TERMINAL:-}" ]] && have "${TERMINAL%% *}"; then
        exec $TERMINAL
    fi

    # Xfce preferred-applications setting
    if have exo-open; then
        exo-open --launch TerminalEmulator && exit 0
    fi

    # Debian alternatives, freedesktop launcher, then common terminals
    for term in x-terminal-emulator xdg-terminal-exec xfce4-terminal \
                gnome-terminal konsole alacritty tilix kitty ghostty xterm; do
        if have "$term"; then
            exec "$term"
        fi
    done

    complain "No terminal emulator found."
    exit 1
}

# tdrop only works on X11 and needs xdotool to manage windows
if [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -z "${DISPLAY:-}" ]] \
   || ! have tdrop || ! have xdotool || ! have xprop || ! have xwininfo || ! have ghostty; then
    open_default_terminal
fi

# Mouse position picks the monitor
X=0; Y=0
eval "$(xdotool getmouselocation --shell 2>/dev/null)"

# Prints "width height x y" for the head under the mouse (or the first head).
# Expects "WxH+X+Y"-style records on stdin as "w h x y" per line.
pick_head() {
    awk -v mx="$X" -v my="$Y" '
        NF == 4 {
            w = $1; h = $2; x = $3; y = $4
            if (!found) { fw = w; fh = h; fx = x; fy = y; found = 1 }
            if (mx >= x && mx < x + w && my >= y && my < y + h) {
                print w, h, x, y; hit = 1; exit
            }
        }
        END { if (!hit && found) print fw, fh, fx, fy }'
}

sw=""
# Xinerama first. With RandR present, the server answers from its current
# layout without probing outputs, so this never stalls the X server.
if have xdpyinfo; then
    read -r sw sh ox oy < <(
        xdpyinfo -ext XINERAMA 2>/dev/null | awk '
            /head #[0-9]+:/ {
                split($3, wh, "x"); split($5, xy, ",")
                print wh[1], wh[2], xy[1], xy[2]
            }' | pick_head
    )
fi

# No Xinerama heads: ask RandR for its monitors. --current keeps xrandr on
# the cached state, though the server may still probe for the monitor list.
if [[ -z "$sw" ]] && have xrandr; then
    read -r sw sh ox oy < <(
        xrandr --current --listactivemonitors 2>/dev/null | awk '
            match($0, /[0-9]+\/[0-9]+x[0-9]+\/[0-9]+\+-?[0-9]+\+-?[0-9]+/) {
                split(substr($0, RSTART, RLENGTH), p, "[/x+]")
                print p[1], p[3], p[5], p[6]
            }' | pick_head
    )
fi

# Neither one answered: use the whole root window
if [[ -z "$sw" ]]; then
    read -r sw sh < <(xwininfo -root | awk '/Width:/{w=$2} /Height:/{h=$2} END{print w, h}')
    ox=0; oy=0
fi

w="$WIDTH"
h="$HEIGHT"
[[ "$w" == *% ]] && w=$(( sw * ${w%\%} / 100 ))
[[ "$h" == *% ]] && h=$(( sh * ${h%\%} / 100 ))

tdrop_args=(-a -x "$ox" -y "$oy" -w "$w" -h "$h")

if have tmux; then
    # -A attaches if the session exists, otherwise creates it
    tdrop "${tdrop_args[@]}" ghostty --window-decoration=none -e tmux -L dropdown new-session -A -s "$SESSION" || open_default_terminal
else
    tdrop "${tdrop_args[@]}" ghostty --window-decoration=none || open_default_terminal
fi
