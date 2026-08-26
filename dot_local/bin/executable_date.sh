#!/bin/sh

if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        :
elif pidof dwl > /dev/null; then
        PID="$(pgrep -u "${LOGNAME}" dwl)"
        DBUS_SESSION_BUS_ADDRESS="$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/"${PID}"/environ | cut -d= -f2-)"
        export DBUS_SESSION_BUS_ADDRESS
fi

notify-send -i clock -a "Date" "$(date +"%b %d %a  %H:%M")"
