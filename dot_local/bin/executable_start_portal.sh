#!/bin/dash

killall "xdg-desktop-portal" "xdg-desktop-portal-hyprland" "xdg-desktop-portal-wlr" 2>/dev/null
sleep 1

libexec="/usr/libexec/xdg-desktop-portal-hyprland"
lib="/usr/lib/xdg-desktop-portal-hyprland"

if [ -x "$libexec" ]; then
    portal_hypr="$libexec"
elif [ -x "$lib" ]; then
    portal_hypr="$lib"
else
    notify-send "start_portal" "xdg-desktop-portal-hyprland not found"
    exit 1
fi

"$portal_hypr" &
sleep 1
/usr/lib/xdg-desktop-portal &
