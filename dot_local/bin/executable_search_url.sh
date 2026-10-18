#!/bin/sh
# Print a search URL prefix: the local SearXNG, else the first server listed in
# ~/.config/searxng/servers (one base URL per line), else DuckDuckGo. Each server
# gets at most 0.3 seconds, so one that is down never holds up a search. A server at
# a private address, such as another computer at home, is tried only while this
# computer reaches it directly over its own network, not through a gateway or a VPN,
# so away from home no search waits for it.

list="${XDG_CONFIG_HOME:-$HOME/.config}/searxng/servers"
servers="http://127.0.0.1:8888"
[ -r "$list" ] && servers="$servers $(grep -Ev '^[[:space:]]*(#|$)' "$list")"

on_local_network() { # ADDRESS
    command -v ip >/dev/null 2>&1 || return 0
    route=$(ip -4 route get "$1" 2>/dev/null) || return 1
    case " $route " in *" via "*) return 1 ;; esac
    device=${route#* dev }
    device=${device%% *}
    # Ethernet and WiFi links have type 1; WireGuard and other tunnels do not.
    [ "$(cat "/sys/class/net/$device/type" 2>/dev/null)" = 1 ]
}

for server in $servers; do
    server="${server%/}"
    host=${server#*://}
    host=${host%%[/:]*}
    case "$host" in
        10.* | 192.168.* | 172.1[6-9].* | 172.2[0-9].* | 172.3[01].*)
            on_local_network "$host" || continue
            ;;
    esac
    if curl -fs -o /dev/null --max-time 0.3 "$server/healthz"; then
        printf '%s/search?q=\n' "$server"
        exit 0
    fi
done
printf '%s\n' 'https://duckduckgo.com/?q='
