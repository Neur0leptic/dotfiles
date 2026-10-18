#!/bin/sh
# iwd configures the address itself (EnableNetworkConfiguration in /etc/iwd/main.conf).

notify() {
	ICON="${XDG_DATA_HOME:-${HOME}/.local/share}/icons/candy-icons/status/scalable/network-wireless-connected-100.svg"
	if [ -f "$ICON" ]; then
		notify-send -i "$ICON" "WiFi" "${1}" 2>/dev/null || true
	else
		notify-send "WiFi" "${1}" 2>/dev/null || true
	fi
}

IFACE="$(iwctl device list 2>/dev/null | awk '/station/{print $2; exit}')"
[ -z "$IFACE" ] && IFACE="$(ip -o link show 2>/dev/null | awk -F': ' '/^[0-9]*: wl/{print $2; exit}')"
[ -z "$IFACE" ] && {
	notify "No wireless interface found"
	exit 1
}

# Strip ANSI codes and extract SSID from iwctl tabular output
# Handles multi-word SSIDs by removing known trailing columns
filter_ssids() {
	sed 's/\x1b\[[0-9;]*m//g
	     /^[[:space:]]*$/d
	     /[Nn]ame\|[Nn]etwork\|^[[:space:]>]*---/d
	     s/[[:space:]]\{2,\}\(psk\|open\|8021x\).*$//
	     s/^[[:space:]>]*//
	     s/[[:space:]]*$//'
}

get_security() {
	ssid="$1"
	iwctl station "$IFACE" get-networks 2>/dev/null |
		sed 's/\x1b\[[0-9;]*m//g
		     /^[[:space:]]*$/d
		     /[Nn]ame\|[Nn]etwork\|^[[:space:]>]*---/d' |
		while IFS= read -r line; do
			name_part=$(printf '%s' "$line" |
				sed 's/[[:space:]]\{2,\}\(psk\|open\|8021x\).*$//; s/^[[:space:]>]*//; s/[[:space:]]*$//')
			if [ "$name_part" = "$ssid" ]; then
				printf '%s' "$line" |
					sed 's/.*[[:space:]]\{2,\}\(psk\|open\|8021x\).*$/\1/'
				break
			fi
		done
}

CURRENT_SSID="$(iwctl station "$IFACE" show 2>/dev/null |
	awk '/Connected/{for(i=1;i<NF;i++) if($i=="network") print $(i+1)}')"

known_ssid() {
	iwctl known-networks list 2>/dev/null | filter_ssids | grep -qF "$1"
}

SSID="$(iwctl station "$IFACE" get-networks 2>/dev/null |
	filter_ssids |
	awk '!seen[$0]++' |
	while IFS= read -r line; do
		printf "%s\0icon\037network-wireless-connected-100\n" "$line"
	done | rofi -dmenu -show-icons -p "Select SSID" -theme-str "window { width: 50ch; }")"

[ -z "$SSID" ] && exit 0

[ -n "$CURRENT_SSID" ] && [ "$CURRENT_SSID" = "$SSID" ] && exit 0

SEC_TYPE="$(get_security "$SSID")"

P=""
if known_ssid "$SSID"; then
	iwctl station "$IFACE" connect "$SSID" 2>/dev/null
elif [ "$SEC_TYPE" = "open" ]; then
	iwctl station "$IFACE" connect "$SSID" 2>/dev/null
else
	P="$(printf '' | rofi -dmenu -password -p "Password for ${SSID}" -theme-str "window { width: 45ch; }")"
	[ -z "$P" ] && exit 0
	# Passphrase passed via CLI arg -- visible in ps on multi-user systems
	iwctl --passphrase "$P" station "$IFACE" connect "$SSID" 2>/dev/null
fi

for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
	# Exactly "connected": "disconnected" contains the same word.
	iwctl station "$IFACE" show 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' |
		awk '$1 == "State" && $2 == "connected" { found = 1 } END { exit !found }' && {
		notify "Connected to ${SSID}"
		exit 0
	}
	sleep 1
done

notify "Failed to connect to ${SSID} after 15s"
exit 1
