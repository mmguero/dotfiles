#!/usr/bin/env bash

if [ -z "$1" ]; then
  SLEEP_SEC=20
else
  SLEEP_SEC="$1"
fi
sleep $SLEEP_SEC

export DISPLAY=:0
nohup /usr/bin/keepassxc </dev/null >/dev/null 2>&1 &
