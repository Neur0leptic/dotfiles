#!/bin/sh
# Screen brightness on one perceptual scale for the keys, Waybar and the login level.
# With exponent 2 every 5% step changes the panel visibly; the notification shows the
# same percentage. Without an argument it only shows the current level.

exponent=2
floor=2

case "${1:-}" in
        up) brightnessctl -q -e"$exponent" -n"$floor" set 5%+ ;;
        down) brightnessctl -q -e"$exponent" -n"$floor" set 5%- ;;
        set)
                brightnessctl -q -e"$exponent" -n"$floor" set "${2:?usage: brightness.sh set PERCENT}%"
                exit
                ;;
        "") ;;
        *)
                echo "Usage: brightness.sh [up|down|set PERCENT]" >&2
                exit 1
                ;;
esac

brightness="$(brightnessctl -e"$exponent" -m info | cut -d, -f4 | tr -d '%')"

icon="${XDG_DATA_HOME:-${HOME}/.local/share}/icons/candy-icons/preferences/scalable/preferences-desktop-display.svg"

notify-send -h string:x-canonical-private-synchronous:brightness -a "Brightness" -i "$icon" -h "int:value:${brightness}" "Brightness  ${brightness}%" ""
