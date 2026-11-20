#!/bin/dash

set -eu
librewolf --headless >/dev/null 2>&1 &
sleep 3
killall librewolf 2>/dev/null || true

# LibreWolf keeps an existing ~/.librewolf profile; new profiles go under XDG_CONFIG_HOME.
profile_root="${XDG_CONFIG_HOME:-${HOME}/.config}/librewolf/librewolf"
[ ! -e "${HOME}/.librewolf/profiles.ini" ] || profile_root="${HOME}/.librewolf"
profile_dir=$(sed -n '/^\[Install/,/^\[/{/^Default=/{s/^Default=//p;q}}' "${profile_root}/profiles.ini")
cd "${profile_root}/${profile_dir}"

curl -sLO https://raw.githubusercontent.com/arkenfox/user.js/master/user.js
curl -sLO https://raw.githubusercontent.com/arkenfox/user.js/master/updater.sh
curl -sLO https://raw.githubusercontent.com/arkenfox/user.js/master/prefsCleaner.sh
chmod +x updater.sh prefsCleaner.sh

./updater.sh -s -n
./prefsCleaner.sh -s -d
librewolf --headless >/dev/null 2>&1 &
sleep 3
killall librewolf 2>/dev/null || true
