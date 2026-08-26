#!/bin/bash
pgrep -x waybar && killall waybar || waybar &
