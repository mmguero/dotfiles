#!/bin/bash

if [ -n "$1" ]; then
    OUTFILE="$1"
else
    TIME=$(date +%d-%b-%y_%H%M-%Z)
    OUTFILE="recording_$TIME.mp4"
fi

FRAME_RATE=${REC_FRAME_RATE:-30}
SIZE=${REC_SIZE:-640x480}
VIDEO_DEV=${REC_VIDEO_DEV:-/dev/video0}
AUDIO_DEV=${REC_AUDIO_DEV:-hw:1,0}
AUDIO_CHANNELS=${REC_AUDIO_CHANNELS:-1}
AUDIO_FREQ=${AUDIO_FREQ:-44100}
THREADS=${THREADS:-0}
VPRESET=${VPRESET:-ultrafast}

#echo "Grabando..."
ffmpeg \
  -f v4l2 -framerate $FRAME_RATE -video_size $SIZE -i "$VIDEO_DEV" \
  -f alsa -ar $AUDIO_FREQ -ac $AUDIO_CHANNELS -i "$AUDIO_DEV" \
  -threads $THREADS \
  -vcodec libx264 -preset $VPRESET \
  "$OUTFILE"
