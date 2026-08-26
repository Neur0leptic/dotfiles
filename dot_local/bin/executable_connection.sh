#!/bin/sh

while ! ping -c 1 "9.9.9.9"; do
        doas busybox udhcpc -i "wlan0" -s "/etc/udhcpc/default.script"
        sleep "0.5"
done
notify-send -i network-wireless "Connected"
