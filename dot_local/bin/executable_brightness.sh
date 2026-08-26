#!/bin/sh

get_brightness="$(brightnessctl g)"
max_brightness="$(brightnessctl m)"
brightness="$(awk "BEGIN {printf \"%.0f\", ($get_brightness / $max_brightness) * 100}")"

icon="${XDG_DATA_HOME:-${HOME}/.local/share}/icons/candy-icons/preferences/scalable/preferences-desktop-display.svg"

notify-send -h string:x-canonical-private-synchronous:brightness -a "Brightness" -i "$icon" -h "int:value:${brightness}" "Brightness  ${brightness}%" ""
