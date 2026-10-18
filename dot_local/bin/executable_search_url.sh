#!/bin/sh
# Print a search URL prefix: the local SearXNG, else the first server listed in
# ~/.config/searxng/servers (one base URL per line), else DuckDuckGo. Each server
# gets at most 0.3 seconds, so one that is down never holds up a search.

list="${XDG_CONFIG_HOME:-$HOME/.config}/searxng/servers"
servers="http://127.0.0.1:8888"
[ -r "$list" ] && servers="$servers $(grep -Ev '^[[:space:]]*(#|$)' "$list")"

for server in $servers; do
    server="${server%/}"
    if curl -fs -o /dev/null --max-time 0.3 "$server/healthz"; then
        printf '%s/search?q=\n' "$server"
        exit 0
    fi
done
printf '%s\n' 'https://duckduckgo.com/?q='
