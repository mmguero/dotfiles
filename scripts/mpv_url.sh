#!/usr/bin/env bash

[[ -r "$HOME"/.bashrc.d/04_envs.bashrc ]] && . "$HOME"/.bashrc.d/04_envs.bashrc

URL="$(xsel -o 2>/dev/null)"
URL_LENGTH=${#URL}
[[ -n $URL ]] && (( $URL_LENGTH > 6 )) && mpv "$URL"
