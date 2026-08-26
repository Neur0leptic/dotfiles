#!/bin/dash

get_volume="$(wpctl get-volume "@DEFAULT_AUDIO_SINK@")"
volume="$(echo "${get_volume}" | awk '/[0-9].*/ {printf "%.0f", ($2 * 100)}')"

if echo "${get_volume}" | grep -q "MUTED" || [ "${volume}" -eq "0" ] 2> /dev/null; then
        icon="audio-volume-muted"
else
        if [ "${volume}" -le "33" ]; then
                icon="audio-volume-low"
        elif [ "${volume}" -le "66" ]; then
                icon="audio-volume-medium"
        else
                icon="audio-volume-high"
        fi
fi
icon="${HOME}/.local/share/icons/candy-icons-vol/${icon}.svg"

notify-send -h string:x-canonical-private-synchronous:volume -a "Volume" -i "$icon" -h "int:value:${volume}" "Volume  ${volume}%" ""
