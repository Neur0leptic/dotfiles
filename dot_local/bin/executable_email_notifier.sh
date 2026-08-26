#!/bin/sh
. $HOME/.config/aerc/email-check.conf
result=$(printf "1 LOGIN \"%s\" \"%s\"\r\n2 SELECT INBOX\r\n3 SEARCH UNSEEN\r\n4 LOGOUT\r\n" \
    "$GMAIL_USER" "$GMAIL_PASS" |
    timeout 15 openssl s_client -connect imap.gmail.com:993 -quiet 2>/dev/null)
count=$(echo "$result" | awk '/^\* SEARCH/ {for(i=3;i<=NF;i++) c++} END {print c}')
[ "${count:-0}" -gt 0 ] && notify-send -u low -t 5000 \
    -i "${XDG_DATA_HOME:-${HOME}/.local/share}/icons/candy-icons/status/scalable/mail-unread.svg" \
    "Mail" "$count new message(s)"
