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

if have tmux; then
    # -A attaches if the session exists, otherwise creates it
    tdrop -ma -w "$WIDTH" -h "$HEIGHT" \
        ghostty -e tmux new-session -A -s "$SESSION" || open_default_terminal
else
    tdrop -ma -w "$WIDTH" -h "$HEIGHT" ghostty || open_default_terminal
fi
