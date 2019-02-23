#!/bin/bash

for file in "$@"; do
  if [[ -f "$file" ]]; then
	#that line will delete all the text after the date but keep the file extension.
	nfile=$(echo "$file" | sed "s/\(20[0-1][0-9]\).*\(mkv\|avi\|mpeg\|mpg\|mp4\)/\1.\2/")

	#that line will delete all the text after the date but keep the file extension.
	nfile=$(echo "$nfile" | sed "s/\(s[0-9][0-9]e[0-9][0-9]\).*\(mkv\|avi\|mpeg\|mpg\|mp4\)/\1.\2/I")

	#this line is going to try to delete a space a the start of the filename if it exist
	nfile=$(echo "$nfile" | sed  "s/\/ /\//")

	#this line is going to delete double dots in the filename and replace them with simple dots
	nfile=$(echo "$nfile" | sed -e "s/\.\./\./g")

	#that line is going to delete everything between [] including the [] 
	nfile=$(echo "$nfile" | sed -e 's/\[[^][]*\]//g')

	if [[ "$file" != "$nfile" ]]; then
	   mv -v -n "$file" "$nfile"
	   # echo "moving \"$file\" to \"$nfile\""
	fi
  fi
done