#!/bin/sh

# Detect running compositor and get D-Bus session
for comp in dwl Hyprland; do
    if pidof "$comp" >/dev/null 2>&1; then
        COMPOSITOR="$comp"
        break
    fi
done

[ -z "$COMPOSITOR" ] && exit 0

# Use existing D-Bus or scrape from compositor's environment
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    PID=$(pgrep -u "$LOGNAME" "$COMPOSITOR" 2>/dev/null | head -1)
    [ -n "$PID" ] && DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/"$PID"/environ 2>/dev/null | tr -d '\0' | cut -d= -f2-)
    [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && export DBUS_SESSION_BUS_ADDRESS
fi

[ -z "$DBUS_SESSION_BUS_ADDRESS" ] && exit 0

read -r b < /sys/class/power_supply/BAT0/capacity 2>/dev/null || exit 0

notify() { notify-send "Battery" "${b}%"; }

[ "$b" -le 7 ] && notify
[ "$b" -eq 25 ] && notify
[ "$b" -eq 50 ] && notify
