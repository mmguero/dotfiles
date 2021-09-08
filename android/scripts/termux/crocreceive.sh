#!/data/data/com.termux/files/usr/bin/bash

# set -e

export DOWNLOAD_DIR=/storage/DEAD-BEEF/Android/data/com.termux/files/Download
export CROC_RELAY=example.org:8000
export CROC_PASS=password

pushd "$DOWNLOAD_DIR"/ >/dev/null 2>&1
croc --yes "$@"
ls -l
popd >/dev/null 2>&1
