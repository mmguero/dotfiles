#!/usr/bin/env bash

# takes a screenshot of the currently active window

# https://gist.github.com/mmguero/95f62f32b44083913708e0d7929ad134

import -window "$(xdotool getwindowfocus getactivewindow)" ./screenshot-"$(date +%Y%m%d_%H%M%S)".png
