#!/bin/dash

torname="$(transmission-remote -l | sed -n '/^ *[0-9]\+ \+100%/{s/^ *\(\([^ ]* *\)\{9\}\)//p}')"

notify-send "Transmission" "\"${torname}\" downloaded"
