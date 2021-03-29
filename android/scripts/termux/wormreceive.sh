#!/data/data/com.termux/files/usr/bin/bash

# set -e

export DOWNLOAD_DIR=/storage/DEAD-BEEF/Android/data/com.termux/files/Download

pushd "$DOWNLOAD_DIR"/ >/dev/null 2>&1
echo 'y' | wormhole --transit-helper tcp:example.org:4001 receive "$@"
ls -l
popd >/dev/null 2>&1
