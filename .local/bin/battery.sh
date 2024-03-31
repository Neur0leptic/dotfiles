#!/bin/sh
pidof dwl >/dev/null || exit "0"
PID="$(pgrep -u "${LOGNAME}" dwl)"
DBUS_SESSION_BUS_ADDRESS="$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/"${PID}"/environ|cut -d= -f2-)"
export DBUS_SESSION_BUS_ADDRESS
read -r b < "/sys/class/power_supply/BAT0/capacity"
n() { notify-send "Battery" "${b}%";}
[ "${b}" -le "7" ] && n || { [ "${b}" -eq "25" ] && n;} || {
[ "${b}" -eq "50" ] && n;} || { [ "${b}" -eq "100" ] && n; }
