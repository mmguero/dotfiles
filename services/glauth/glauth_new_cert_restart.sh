#!/usr/bin/env bash

SCRIPT_PATH="$(dirname $(realpath -e "${BASH_SOURCE[0]}"))"
pushd "$SCRIPT_PATH" >/dev/null 2>&1

sed -i "s/^\([[:space:]]*#[[:space:]]*date\)[[:space:]]*=.*/\1 = $(date +%Y-%m-%dT%H:%M:%S%z)/" ./glauth.cfg
killall glauth

popd >/dev/null 2>&1

