#!/bin/sh
PHYS="$(ip route show default 2> /dev/null | awk '{for(i=1;i<NF;i++) if($i=="dev") print $(i+1)}' | head -1)"

if [ -n "$(sudo wg show interfaces 2> /dev/null)" ]; then
        echo '{"text":"","class":"vpn","tooltip":"VPN: Mullvad (WireGuard)"}'
elif [ -n "$PHYS" ] && resolvectl dns "$PHYS" 2> /dev/null | grep -q "9.9.9.9"; then
        echo '{"text":"Q9","class":"vpn-off","tooltip":"DNS: Quad9"}'
else
        echo '{"text":"","class":"vpn-none","tooltip":"VPN: kapalı"}'
fi
