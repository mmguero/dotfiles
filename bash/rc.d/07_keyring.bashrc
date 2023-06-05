if [[ -n "$DESKTOP_SESSION" ]] && ! pidof pidof gnome-keyring-daemon >/dev/null 2>&1 && command -v gnome-keyring-daemon >/dev/null 2>&1; then
    eval $(gnome-keyring-daemon --start)
    export SSH_AUTH_SOCK
fi
