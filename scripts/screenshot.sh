#!/bin/bash
DATE=`date +%Y%m%d_%H%M%S`
import -window "$(xdotool getwindowfocus getactivewindow)" "$HOME/Desktop/screenshot-$DATE.png"
