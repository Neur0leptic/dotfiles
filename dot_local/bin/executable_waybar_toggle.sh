#!/bin/sh

uid=$(id -u)
if pgrep -x -u "$uid" waybar >/dev/null 2>&1; then
    pkill -TERM -x -u "$uid" waybar
    exit 0
fi

log="${XDG_CACHE_HOME:-$HOME/.cache}/waybar.log"
mkdir -p "$(dirname "$log")"
if [ -n "${DWL_SESSION:-}" ]; then
    waybar -c "$HOME/.config/waybar/config-dwl.jsonc" \
        -s "$HOME/.config/waybar/style-dwl.css" >>"$log" 2>&1 &
elif [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    waybar >>"$log" 2>&1 &
else
    printf 'cannot determine the active compositor\n' >&2
    exit 1
fi
