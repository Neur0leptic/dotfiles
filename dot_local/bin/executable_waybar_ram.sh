#!/bin/sh
while read -r k v _; do case "$k" in MemTotal:) mt=$v ;; MemAvailable:) ma=$v ;; esac done < /proc/meminfo
m=$(((mt - ma) * 100 / mt))
tooltip_text=$(~/.local/bin/waybar_system.sh | jq -r '.text // empty')
jq -cn --arg text "󰍛 ${m}%" --arg tooltip "$tooltip_text" '{text: $text, tooltip: $tooltip}'
