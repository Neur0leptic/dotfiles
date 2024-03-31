#!/bin/bash

create_brightness_bar() {
    max_width=20
    filled_block="█"
    empty_block="░"

    current_width=$((bright * max_width / 100))
    filled=$(printf "%${current_width}s")
    empty=$(printf "%$((max_width - current_width))s")

    bar="${filled// /$filled_block}${empty// /$empty_block}"
    echo "$bar"
}

get_brightness_status() {
	bright=$(brightnessctl get-brightness | grep -o "[0-9].*")
}

send_notification() {
    icon=" "
    bar=$(create_brightness_bar)
    message="${icon} ${bar} ${bright}%"
    dunstify --replace=5555 "$message"
}

get_brightness_status
send_notification
