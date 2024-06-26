#!/bin/dash

get_volume="$(wpctl get-volume "@DEFAULT_AUDIO_SINK@")"
volume="$(echo "${get_volume}" | awk '/[0-9].*/ {print ($2 * 100)}')"
filled_blocks="$((volume / 5))"

bar=""

for i in $(seq "1" "${filled_blocks}"); do bar="${bar}█"; done

for i in $(seq "1" "$((20 - filled_blocks))"); do bar="${bar}░"; done

[ "${volume}" -le "35" ] && icon="🔈" || {
        [ "${volume}" -le "70" ] && icon="🔉" || icon="🔊"
}
{ echo "${get_volume}" | grep -q "MUTED" || [ "${volume}" -eq "0" ]; } && icon="🔇"

makoctl dismiss -a
notify-send "${icon} ${bar} ${volume}%"
