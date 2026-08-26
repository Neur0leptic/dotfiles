#!/bin/sh

t="$(date +"🗓 %b %d %a  ┃ 🕒 %H:%M")"

ip route get "9.9.9.9" | rg -q 'wlan0' && n="🛜" || n="🔌"
ping -c "1" -W "0.4" "8.8.8.8" > "/dev/null" 2>&1 || n="❌"

d=" 💾$(df --output=pcent /home | tail -n "1")"

wi="$(wg show interfaces | rg -o '^[^-]*-[^-]*')"
[ "${wi}" ] && w="🔐 " || w="🔓"

read -r b < "/sys/class/power_supply/BAT0/capacity"
read -r st < "/sys/class/power_supply/BAT0/status"

[ "${st}" = "Charging" ] || [ "${st}" = "Full" ] && s=" ⚡️%" || {
        [ "${b}" -gt "40" ] && s=" 🔋%" || s=" 🪫%"
}

[ "${b}" ] || s=" ⚡️"

uf="/tmp/updates.txt"

up() {
        (
                if [ -f /etc/gentoo-release ]; then
                        su="doas"
                        command -v doas > /dev/null 2>&1 || su="sudo"
                        $su emaint sync -a > "/dev/null" 2>&1
                        emerge -pvu @world 2> /dev/null | rg -c '^\[ebuild' > "${uf}"
                else
                        checkupdates 2> /dev/null | wc -l > "${uf}"
                fi
        ) < "/dev/null" > "/dev/null" 2>&1 &
}

nt="$(date +%s)"
ot="$((nt - 7200))"
m="$(stat -c %Y "${uf}" 2> "/dev/null" || echo "0")"

[ ! -e "${uf}" ] || [ "${m}" -lt "${ot}" ] && {
        (up &)
        u=""
} || u="┃ 🚀 $(cat "${uf}")"

m2="    ${n} ┃ ${w}${wi:-} ┃${d} ┃${s} ${b}${u:-}

      ${t}"

notify-send -i " " -u "Critical" "${m2}"

L="$(curl -fsSk "ipinfo.io/city")"
curl -fsSk "wttr.in/${L}?format=%c%t|%c%f|%h|%u|%p|%w|%m|%D|%S|%z|%s|%d" > "/tmp/crw.txt" &
curl -fsSk "rate.sx/{1BTC,1ETH,1XMR}" > "/tmp/crr.txt" &
wait

IFS='|' read -r wt wtf wth wtu wtp wtw mn wtd wtr wtz wts wtdu < "/tmp/crw.txt"

{
        read -r btc
        read -r eth
        read -r xmr
} < "/tmp/crr.txt"

wt="$(printf "%s\n" "${wt}" | sed -E 's/ //g; s/(°C|°F)//g')"
wtf="🥵$(printf "%s\n" "${wtf}" | rg -o '[+-]\d+')"
wth="💧${wth}"
wtu="🕶 ${wtu}"
wtp="☔️${wtp%mm}"
wtw="💨 $(printf "%s\n" "${wt}" | rg -o '.\d+')"
wtd="🌄 ${wtd%???}"
wtr="🌅 ${wtr%???}"
wtz="🌞 ${wtz%???}"
wts="🌇 ${wts%???}"
wtdu="🌆 ${wtdu%???}"
btc="₿ ${btc%%.*}"
eth="💎 ${eth%%.*}"
xmr="Ⓜ️  ${xmr%%.*}"

m="${mn} ┃ ${wt} ┃ ${wtf}  ┃${wth} ┃${wtp} ┃ ${wtu} ┃ ${wtw}

${wtd} ┃ ${wtr} ┃ ${wtz} ┃ ${wts} ┃ ${wtdu}

    ${btc} ┃ ${eth} ┃ ${xmr}"

notify-send -i " " -u "Critical" "${m}"
