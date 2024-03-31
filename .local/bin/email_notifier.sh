#!/bin/dash

PID="$(pgrep -u "${LOGNAME}" dwl)"
DBUS_SESSION_BUS_ADDRESS="$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/"${PID}"/environ|cut -d= -f2-)"
export DBUS_SESSION_BUS_ADDRESS

# mailsync

# NEWMAILS="$(find '/home/*/.local/share/mail/*/*/new' -type f)"

# [ -z "${NEWMAILS}" ] && exit

# count="$(printf "%s\n" "${NEWMAILS}" | wc -l)"

# notify-send -u critical "You have ${count} new e-mails."
