#!/data/data/com.termux/files/usr/bin/bash

# set -e

export DOWNLOAD_DIR=/data/data/com.termux/files/home/storage/external-download

pushd "$DOWNLOAD_DIR"/ >/dev/null 2>&1
croc --yes --relay "example.org:9009" "$@"
ls -l
popd >/dev/null 2>&1
