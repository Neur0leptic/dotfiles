#!/bin/dash

set -eu
librewolf --headless >/dev/null 2>&1 &
sleep 3
killall librewolf 2>/dev/null || true

profile_dir=$(sed -n '/^\[Install/,/^\[/{/^Default=/{s/^Default=//p;q}}' "${HOME}/.librewolf/profiles.ini")
cd "${HOME}/.librewolf/${profile_dir}"

curl -sLO https://raw.githubusercontent.com/arkenfox/user.js/master/user.js
curl -sLO https://raw.githubusercontent.com/arkenfox/user.js/master/updater.sh
curl -sLO https://raw.githubusercontent.com/arkenfox/user.js/master/prefsCleaner.sh
chmod +x updater.sh prefsCleaner.sh

./updater.sh -s -n
./prefsCleaner.sh -s -d
librewolf --headless >/dev/null 2>&1 &
sleep 3
killall librewolf 2>/dev/null || true
