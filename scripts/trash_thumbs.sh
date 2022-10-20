#!/usr/bin/env bash

find ~/.cache/thumbnails -type f -print -exec shred -n0 -z -u "{}" \;
find ~/.thumbnails -type f -print -exec shred -n0 -z -u "{}" \;
