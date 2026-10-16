#!/bin/sh
PHYS="$(ip route show default 2> /dev/null | awk '{for(i=1;i<NF;i++) if($i=="dev") print $(i+1)}' | head -1)"

quad9() {
        [ -n "$PHYS" ] || return 1
        if command -v resolvectl > /dev/null 2>&1 && resolvectl dns > /dev/null 2>&1; then
                resolvectl dns "$PHYS" 2> /dev/null | grep -q "9.9.9.9"
        else
                # Without systemd-resolved every server in resolv.conf must be Quad9.
                awk '$1 == "nameserver" { n++; if ($2 !~ /^(9\.9\.9\.9|149\.112\.112\.112|2620:fe::(fe|9))$/) other = 1 }
                        END { exit !(n && !other) }' /etc/resolv.conf 2> /dev/null
        fi
}

if [ -n "$(ip -o link show up type wireguard 2> /dev/null)" ]; then
        echo '{"text":"","class":"vpn","tooltip":"VPN: Mullvad (WireGuard)"}'
elif quad9; then
        echo '{"text":"Q9","class":"vpn-off","tooltip":"DNS: Quad9"}'
else
        echo '{"text":"","class":"vpn-none","tooltip":"VPN: kapalı"}'
fi
