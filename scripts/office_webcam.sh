#!/bin/bash

set -e

CAMERA_DEVICE=$(v4l2-ctl --list-devices | grep -A 1 "UVC" | grep "/dev/video" | head -n 1 | awk '{print $1}')
INPUT_FORMAT=mjpeg
FRAMERATE=25
RESOLUTION=1280x960
MOTION_THRESHOLD=0.0001

OUT_FILE_CODEC=libx264
OUT_FILE_CODEC_FLAGS="-preset faster -tune zerolatency -crf 21 -movflags +faststart"
OUT_FILE_FORMAT=mp4
OUT_FILE_SEGMENT_TIME=3600

OUT_STREAM_CODEC=mpeg2video
OUT_STREAM_RATE=8000000
OUT_STREAM_FORMAT=mpegts
OUT_STREAM_DEST=udp://localhost:44836

while [ true ]; do
  OUT_FILENAME=$(date +"%Y-%m-%d_%H-%M-%S.mp4")
  ffmpeg -nostats -loglevel panic \
    -f v4l2 -input_format $INPUT_FORMAT -framerate $FRAMERATE -video_size $RESOLUTION \
    -fflags nobuffer -t $OUT_FILE_SEGMENT_TIME -i $CAMERA_DEVICE \
    -an -vf "select=gt(scene\,$MOTION_THRESHOLD),setpts=N/($FRAMERATE*TB)" \
    -f $OUT_FILE_FORMAT -vcodec $OUT_FILE_CODEC $OUT_FILE_CODEC_FLAGS ./"$OUT_FILENAME" \
    -an -f $OUT_STREAM_FORMAT -vcodec $OUT_STREAM_CODEC -b $OUT_STREAM_RATE  $OUT_STREAM_DEST
  sleep 1
done
