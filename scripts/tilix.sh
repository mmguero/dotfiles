#!/usr/bin/env bash

[[ -e /etc/profile.d/vte.sh ]] && source /etc/profile.d/vte.sh >/dev/null 2>&1 || source /etc/profile.d/vte-*.sh >/dev/null 2>&1

[[ -r ~/.config/tilix.dconf ]] && dconf load /com/gexperts/Tilix/ < ~/.config/tilix.dconf && rm -f ~/.config/tilix.dconf

nohup /usr/bin/tilix "$@" </dev/null >/dev/null 2>&1 &
