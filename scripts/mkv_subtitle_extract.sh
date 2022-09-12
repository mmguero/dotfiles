#!/usr/bin/env bash

shopt -s nocasematch

toolPath=''

# =============================================================================
# Start of script

# If no directory is given, work in local dir
if [ "$1" = "" ]; then
  DIR="."
else
  DIR="$1"
fi

if [ "$2" = "" ]; then
  ONLY_LANG=
else
  ONLY_LANG="$2"
fi

# Get all the MKV/MP4 files in this dir and its subdirs
find "$DIR" -type f \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' \) | while read filename
do
  echo "Processing file $filename:"

  # Get base file name (without extension)
  fileBasename=${filename%.*}

  # Parse info about all subtitles tracks from file
  # This will output lines in this format, one line per subtitle track, fields delimited by tabulator:
  #   trackID <tab> trackLanguage <tab> trackCodecID <tab> trackCodec
  "${toolPath}mkvmerge" -J "$filename" | python -c "exec(\"import sys, json;\nfor track in json.load(sys.stdin)['tracks']:\n\tif track['type'] == 'subtitles':\n\t\tprint(str(track['id']) + '\t' + track['properties']['language'] + '\t' + track['properties']['codec_id'] + '\t' + track['codec'])\")" | while IFS=$'\t' read -r trackNumber trackLanguage trackCodecID trackCodec;
  do
    # optional: process only some types of subtitle tracks (according to $trackCodecID)
    #   See codec types here: https://tools.ietf.org/id/draft-lhomme-cellar-codec-00.html#rfc.section.6.5
    if [[ $trackCodecID == 'S_VOBSUB' || $trackCodecID == 'unwantedID_#2' ]] || ( [[ -n "$ONLY_LANG" ]] && [[ "$ONLY_LANG" != "$trackLanguage" ]] ); then
      echo "  skipping track #${trackNumber}: $trackLanguage ($trackCodec, $trackCodecID)"
      continue;
    fi

    echo "  extracting track #${trackNumber}: $trackLanguage ($trackCodec, $trackCodecID)"

    trackSuffix="$(echo "$trackCodec" | tr '[:upper:]' '[:lower:]' | cut -d'/' -f2)"

    # extract track with language and track id
    `"${toolPath}mkvextract" tracks "$filename" $trackNumber:"$fileBasename.$trackNumber.$trackLanguage.$trackSuffix" > /dev/null 2>&1`
  done
done
