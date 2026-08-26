#!/bin/dash
while ! ping -c 1 "9.9.9.9"; do sleep "0.5"; done
notify-send -i RSS_feeds -a "" "Connected to the internet!"

# Get the number of unread articles
NEW_ITEMS=$(newsboat -x reload print-unread | grep -oP '^\d+')

# Check if NEW_ITEMS is a valid number and greater than 0
if [ -n "$NEW_ITEMS" ] && [ "$NEW_ITEMS" -gt 0 ]; then
        notify-send -i RSS_feeds -a "Newsboat" "You have $NEW_ITEMS new unread articles"
fi
