#!/bin/sh

layout=""
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    layout=$(hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main == true) | .active_keymap')
elif [ -n "${DWL_SESSION:-}" ]; then
    keymap_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/dwl-keymap"
    if [ -r "$keymap_file" ]; then
        layout=$(cat "$keymap_file" 2>/dev/null)
    fi
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
