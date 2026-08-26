#!/bin/sh

# Try hyprctl first (Arch/Hyprland)
layout=$(hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main == true) | .active_keymap')

# Fall back to dwl kblayout file (Gentoo/dwl + kblayout patch)
if [ -z "$layout" ] && [ -r /tmp/dwl-keymap ]; then
    layout=$(cat /tmp/dwl-keymap 2>/dev/null)
fi

[ -z "$layout" ] && layout="unknown"

case "$layout" in
	*English*|us)            short="EN" ;;
	*Turkish*|tr)            short="TR" ;;
	*German*|de)             short="DE" ;;
	*) short="$(printf '%s' "$layout" | cut -c1-2 | tr '[:lower:]' '[:upper:]')" ;;
esac

notify-send -u low -a "Keyboard" -t 1200 \
	-h string:x-canonical-private-synchronous:keyboard \
	-i "${XDG_DATA_HOME:-${HOME}/.local/share}/icons/candy-icons/devices/scalable/input-keyboard.svg" \
	"${short}" "${layout}"
