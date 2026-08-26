#!/bin/bash

MENU="Lock\0icon\x1fsystem-lock-screen
Shutdown\0icon\x1fsystem-shutdown
Reboot\0icon\x1fsystem-reboot
Logout\0icon\x1fxfsm-logout
Suspend\0icon\x1fsystem-suspend
Screen Saver\0icon\x1fsleep"

MAX_CHARS=$(echo -e "$MENU" | awk -F'\0' '{print length($1)}' | sort -rn | head -1)
[ -z "$MAX_CHARS" ] || [ "$MAX_CHARS" -eq 0 ] && MAX_CHARS=10
WIDTH=$((MAX_CHARS + 15))
[ "$WIDTH" -lt 25 ] && WIDTH=25

CHOICE="$(echo -e "$MENU" | rofi -dmenu -i -show-icons -no-fixed-num-lines -p "Power:" -theme-str "window {width: ${WIDTH}ch;}")"

if [ -f /etc/gentoo-release ]; then
        SUSPEND="doas sh -c 'echo mem > /sys/power/state'"
        POWEROFF="doas openrc-shutdown -p now"
        REBOOT="doas openrc-shutdown -r now"
        WM_EXIT="pkill dwl"
else
        SUSPEND="systemctl suspend"
        POWEROFF="systemctl poweroff"
        REBOOT="systemctl reboot"
        WM_EXIT="hyprctl dispatch exit"
fi
LOCK_CMD="swaylock"

case "${CHOICE}" in
        "Shutdown") $POWEROFF ;;
        "Reboot") $REBOOT ;;
        "Lock") $LOCK_CMD ;;
        "Logout") $WM_EXIT ;;
        "Suspend") $SUSPEND ;;
        "Screen Saver") kitty --class fullscreen -e unimatrix ;;
        *) ;;
esac
