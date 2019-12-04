#!/bin/bash

URL="$(xsel -bo 2>/dev/null)"
URL_LENGTH=${#URL}
[[ -n $URL ]] && (( $URL_LENGTH > 6 )) && mpv "$URL"
