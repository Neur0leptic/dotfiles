#!/bin/sh
while read -r k v _; do case "$k" in MemTotal:) mt=$v ;; MemAvailable:) ma=$v ;; esac done < /proc/meminfo
m=$(((mt - ma) * 100 / mt))
tooltip_text=$(~/.local/bin/waybar_system.sh)
echo "{\"text\": \"󰍛 ${m}%\"}"
cat << EOF
{
  tooltip: ${tooltip_text}
}
EOF
