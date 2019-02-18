#!/bin/bash

(sleep .5 && wmctrl -a Shredder)&
zenity --question --title=Shredder --text='Tonight I dine on turtle soup.' && shred -n0 -z -u "$@"

