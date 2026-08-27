#!/bin/bash

MENU="Lock\0icon\x1fsystem-lock-screen
Shutdown\0icon\x1fsystem-shutdown
Reboot\0icon\x1fsystem-reboot
Logout\0icon\x1fxfsm-logout
Suspend\0icon\x1fsystem-suspend
Screen Saver\0icon\x1fsleep"

notify_error() {
        if command -v notify-send >/dev/null 2>&1; then
                notify-send -u critical "Power menu" "$1"
        else
                printf 'Power menu: %s\n' "$1" >&2
        fi
}

power_backend() {
        if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
                printf '%s\n' systemd
        elif command -v openrc-shutdown >/dev/null 2>&1; then
                printf '%s\n' openrc
        else
                printf '%s\n' unknown
        fi
}

session_backend() {
        if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || pgrep -u "$(id -u)" -x Hyprland >/dev/null 2>&1; then
                printf '%s\n' hyprland
        elif pgrep -u "$(id -u)" -x dwl >/dev/null 2>&1; then
                printf '%s\n' dwl
        else
                printf '%s\n' unknown
        fi
}

do_power_action() {
        local action="$1"

        case "$(power_backend):${action}" in
                systemd:suspend) systemctl suspend ;;
                systemd:poweroff) systemctl poweroff ;;
                systemd:reboot) systemctl reboot ;;
                openrc:suspend) doas sh -c 'echo mem > /sys/power/state' ;;
                openrc:poweroff) doas openrc-shutdown -p now ;;
                openrc:reboot) doas openrc-shutdown -r now ;;
                *) notify_error "No supported power backend was found." ; return 1 ;;
        esac
}

do_logout() {
        case "$(session_backend)" in
                hyprland) hyprctl dispatch exit ;;
                dwl) pkill -TERM -u "$(id -u)" -x dwl ;;
                *) notify_error "No Hyprland or DWL session was found." ; return 1 ;;
        esac
}

MAX_CHARS=$(printf '%b\n' "$MENU" | awk -F'\0' '{print length($1)}' | sort -rn | head -1)
if [ -z "$MAX_CHARS" ] || [ "$MAX_CHARS" -eq 0 ]; then
        MAX_CHARS=10
fi
WIDTH=$((MAX_CHARS + 15))
[ "$WIDTH" -lt 25 ] && WIDTH=25

CHOICE="$(printf '%b\n' "$MENU" | rofi -dmenu -i -show-icons -no-fixed-num-lines -p "Power:" -theme-str "window {width: ${WIDTH}ch;}")"

case "${CHOICE}" in
        "Shutdown") do_power_action poweroff ;;
        "Reboot") do_power_action reboot ;;
        "Lock") swaylock ;;
        "Logout") do_logout ;;
        "Suspend") do_power_action suspend ;;
        "Screen Saver") footclient -a fullscreen unimatrix -c cyan ;;
        *) ;;
esac
