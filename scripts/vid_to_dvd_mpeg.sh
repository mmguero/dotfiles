#!/usr/bin/env bash

set -e

DESTDIR=""
VERBOSE=""
export VIDEO_FORMAT=NTSC

function cleanup {
  rm -rf "$DESTDIR"
}

for file in "$@"
do
  if [[ -f "${file}" ]]; then

  	file_base_name="$(basename "${file}")"
  	file_full_path="$(realpath "${file}")"

    DESTDIR="$(mktemp -d -t vid2dvd-XXXXXX)"
    trap "cleanup" EXIT

    pushd "${DESTDIR}"
    ffmpeg -i "${file_full_path}" -filter:v "scale='w=min(720,trunc((480*33/40*dar)/2+0.5)*2):h=min(480,trunc((720*40/33/dar)/2+0.5)*2)',pad='w=720:h=480:x=(ow-iw)/2:y=(oh-ih)/2',setsar='r=40/33'" -target ntsc-dvd "${file_base_name}.mpeg"
    mkdir dvd
    dvdauthor -o dvd -t "${file_base_name}.mpeg"
    pushd dvd
    dvdauthor -o . -T
    genisoimage -dvd-video -o ../"${file_base_name}.iso" .
    popd
    popd
    mv -v "${DESTDIR}/${file_base_name}.iso" ./
    cleanup
  fi
done
