#!/bin/sh

while ! ping -c "1" "9.9.9.9" > /dev/null 2>&1; do sleep "0.5"; done

hsts_urls="
https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts
https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/pro.txt
https://hosts.ubuntu101.co.za/hosts
"
trckrs_url="https://cf.trackerslist.com/best.txt"

tmp_hsts="$(mktemp)"
tmp_trckrs="$(mktemp)"

hsts="/etc/hosts"
trckrs="${XDG_DATA_HOME}/trackers.txt"

exceptions="
	/0\.twitter\.com/,+172d
	/\.redditmedia\.com/,+75d
"

[ -z "$(command -v doas)" ] && prv="sudo" || prv="doas"

crrction() {
        rg -o '^0[^ ]+ [^ ]+' |
                rg -vF '0.0.0.0 0.0.0.0' |
                sed "${exceptions}" > "${tmp_hsts}"
}

clnup() {
        sed '/^$/d; /^wss/d; s/:/%3A/g; s#/#%2F#g' > "${tmp_trckrs}"
}

ctrl() {
        grep -vxFf "${1}" "${2}"
}

curl -s ${hsts_urls} | crrction
curl -s "${trckrs_url}" | clnup

nhsts="$(ctrl "${hsts}" "${tmp_hsts}" | wc -l)"
ntrckrs="$(wc -l < "${tmp_trckrs}")"

[ "$(wc -l < "${hsts}")" -lt "10" ] && echo " " | ${prv} tee -a "${hsts}" > /dev/null

ctrl "${hsts}" "${tmp_hsts}" | ${prv} tee -a "${hsts}" > /dev/null

cat "${tmp_trckrs}" > "${trckrs}"

[ "${nhsts}" != 0 ] && notify-send -r 5560 "Hosts & Trackers" "${nhsts} new hosts"
[ "${ntrckrs}" != 0 ] && notify-send -r 5560 "Hosts & Trackers" "${ntrckrs} new trackers"

rm -f "${tmp_hsts}" "${tmp_trckrs}"
