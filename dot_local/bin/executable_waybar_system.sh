#!/bin/sh
read -r t < /sys/class/thermal/thermal_zone0/temp
t=$((t / 1000))
while read -r k v _; do case "$k" in MemTotal:) mt=$v ;; MemAvailable:) ma=$v ;; esac done < /proc/meminfo
m=$(((mt - ma) * 100 / mt))
d=$(df -h / | awk 'NR==2{print $5}')
echo "{\"text\": \"󰍛 ${m}%  󰈐 ${t}°   ${d}\"}"
