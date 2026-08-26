#!/bin/sh

n() {
        notify-send "Torrents" "${1}"
}

pr() {
        printf "%s\n" "${@}"
}

m() {
        tmp="/tmp/rofi_m_$$"
        cat > "$tmp"

        # Calculate max visible characters ignoring \0 metadata
        x="$(awk -F'\0' '{print length($1)}' "$tmp" | sort -rn | head -1)"
        [ -z "$x" ] && x=10

        # Ensure it's wide enough for the prompt + some padding
        chk="$(printf '%s' "${1}" | awk '{print length($0)}')"
        [ "$x" -lt "$chk" ] && x="$chk"

        # Add generous padding for icons, prompt and checkboxes
        x=$((x + 18))

        # Clamp between 35 and 70
        [ "$x" -lt 35 ] && x=35
        [ "$x" -gt 70 ] && x=70

        cat "$tmp" | rofi -dmenu -i -show-icons -p "${1}" \
                -theme-str "window { width: ${x}ch; }" "${2:-}"
        rm -f "$tmp"
}

find_id() {
        opts="$(transmission-remote -l | sed -E '1d;$d; s/^ *([0-9]+).*\s{2,}(.+)$/\1 \2/')"
        id="$(pr "${opts}" | m "Torrent List" -multi-select | hck -Ld ' ' -f1)"
}

tor_id() {
        find_id

        for torrent_id in $(pr "${id}"); do
                i="${i}${torrent_id},"
        done

        i="${i%,}"
}

add() {
        MAGNET="$(wl-paste)"

        pr "${MAGNET}" | rg -q '^[0-9a-fA-F]{40}$' && {
                MAGNET="magnet:?xt=urn:btih:${MAGNET}"
        } || {
                pr "${MAGNET}" | rg -q '^magnet:\?xt=urn:btih:[0-9a-fA-F]{40}' || {
                        n "Clipboard not valid"
                        exit
                }
        }

        while read -r tracker; do
                MAGNET="${MAGNET}&tr=${tracker}"
        done < "${XDG_DATA_HOME}/trackers.txt"

        pidof transmission-daemon > "/dev/null" || {
                transmission-daemon
                sleep "3"
        }

        transmission-remote -a "${MAGNET}" &&
                HASH="${MAGNET#*btih:}"
        HASH="${HASH%%&*}"
        n "\"${HASH}\" added."
}

remove() {
        tor_id

        transmission-remote -t ${i} -r && n "${i} removed"
}

tor_prio() {
        tor_id

        PRIORITY="$(printf "High\0icon\037audio-volume-high\nNormal\0icon\037audio-volume-medium\nLow\0icon\037audio-volume-low" | m "Select Priority")"

        case "${PRIORITY}" in
                "High") transmission-remote -t "${id}" -Bh ;;
                "Normal") transmission-remote -t "${id}" -Bn ;;
                "Low") transmission-remote -t "${id}" -Bl ;;
                *) exit ;;
        esac && n "\"${id}\" priority set to ${PRIORITY}."
}

file_prio() {
        find_id

        sel="$(transmission-remote -t "${id}" -f |
                sed -E '1,2d; s/^[ ]*([0-9]+):[ ]+([^ ]+ +){3}([^ ]+ [^ ]+)[ ]+(.*)/\1 \3 \4/' |
                m "Files of ${id}" -multi-select | hck -Ld ' ' -f1)"

        PRIORITY="$(printf "High\0icon\037audio-volume-high\nNormal\0icon\037audio-volume-medium\nLow\0icon\037audio-volume-low\nNo Download\0icon\037media-playback-stopped" | m "Priority")"

        for f in ${sel}; do
                i="${i}${f},"
        done

        i=${i%,}

        case "${PRIORITY}" in
                "High") ARGS="-g ${i} -ph ${i}" ;;
                "Normal") ARGS="-g ${i} -pn ${i}" ;;
                "Low") ARGS="-g ${i} -pl ${i}" ;;
                "No Download") ARGS="-G ${i} -pl ${i}" ;;
                *) exit ;;
        esac

        transmission-remote -t "${id}" ${ARGS}
        n "Prio ${PRIORITY}: ${i}"
}

start_stop() {
        CHOICE="$(printf "Start\0icon\037media-playback-playing\nStop\0icon\037media-playback-paused" | m "Action torrent(s)")"

        tor_id

        case "${CHOICE}" in
                "Start") transmission-remote -t "${i}" --start && n "Started: ${i}" ;;
                "Stop") transmission-remote -t "${i}" --stop && n "Stopped: ${i}" ;;
                *) exit ;;
        esac
}

no_download() {
        tor_id
        transmission-remote -t "${id}" -G "all"
}

# Init system detection
SVC_CTL="systemctl"
SVC_ENABLE="systemctl enable"
SVC_DISABLE="systemctl disable"
SVC_ACTIVE="systemctl is-active --quiet"
command -v rc-service >/dev/null 2>&1 && {
    SVC_CTL="rc-service"
    SVC_ENABLE="rc-update add"
    SVC_DISABLE="rc-update del"
    SVC_ACTIVE="rc-service status >/dev/null 2>&1"
}

install_sv() {
        n "Installing Prowlarr & Flaresolverr from AUR..."
        n "This can take a while..."

        yay -S --noconfirm prowlarr-bin flaresolverr || {
                n "Installation failed. Check your internet connection."
                exit 1
        }

        if command -v rc-service >/dev/null 2>&1; then
                sudo rc-update add prowlarr default || {
                        n "Failed to enable Prowlarr"
                        exit 1
                }
                sudo rc-service prowlarr start || {
                        n "Failed to start Prowlarr"
                        exit 1
                }
                sudo rc-update add flaresolverr default || {
                        n "Failed to enable Flaresolverr"
                        exit 1
                }
                sudo rc-service flaresolverr start || {
                        n "Failed to start Flaresolverr"
                        exit 1
                }
        else
                sudo systemctl enable --now prowlarr.service || {
                        n "Failed to enable Prowlarr service"
                        exit 1
                }
                sudo systemctl enable --now flaresolverr.service || {
                        n "Failed to enable Flaresolverr service"
                        exit 1
                }
        fi

        n "Installation finished successfully"
        n "Services started and enabled"
}

search() {
        # Prowlarr kurulu mu kontrol et
        command -v prowlarr > "/dev/null" || pacman -Q prowlarr-bin > "/dev/null" 2>&1 || {
                SELECTION="$(printf "Yes\0icon\037dialog-yes\nNo\0icon\037dialog-no" | m "Install Prowlarr & Flaresolverr?")"

                [ "${SELECTION}" = "Yes" ] && install_sv || exit
        }

        # Servislerin calisip calismadigini kontrol et
        if command -v rc-service >/dev/null 2>&1; then
                if ! sudo rc-service prowlarr status >/dev/null 2>&1; then
                        n "Starting Prowlarr..."
                        sudo rc-service prowlarr start
                fi
                if ! sudo rc-service flaresolverr status >/dev/null 2>&1; then
                        n "Starting Flaresolverr..."
                        sudo rc-service flaresolverr start
                fi
        else
                systemctl is-active --quiet prowlarr.service || {
                        n "Starting Prowlarr..."
                        sudo systemctl start prowlarr.service
                }
                systemctl is-active --quiet flaresolverr.service || {
                        n "Starting Flaresolverr..."
                        sudo systemctl start flaresolverr.service
                }
        fi

        # Servislerin hazir olmasini bekle
        i="0"
        while [ "${i}" -lt "15" ]; do
                curl -s "http://localhost:9696" > "/dev/null" &&
                        curl -s "http://localhost:8191" > "/dev/null" && break
                i="$((i + 1))"
                sleep "0.5"
        done

        [ "${i}" -lt "15" ] || {
                n "Services did not start properly."
                n "Check: sudo ${SVC_CTL} status prowlarr flaresolverr"
                exit
        }

        n "Prowlarr & Flaresolverr ready"

        librewolf "http://localhost:9696/search"
}

killsv() {
        if command -v rc-service >/dev/null 2>&1; then
                sudo rc-service prowlarr stop 2>/dev/null
                sudo rc-service flaresolverr stop 2>/dev/null
        else
                sudo systemctl stop prowlarr.service flaresolverr.service 2>/dev/null
        fi
        kill -9 $(pgrep -f 'transmission-daemon') 2>/dev/null
        n "Services are closed"
}

list() {
        awk_script='
		BEGIN {
		FS = ": "
		OFS = "\t"
		R="\033[1;91m"
		G="\033[1;92m"
		B="\033[1;94m"
		Y="\033[1;93m"
		C="\033[1;96m"
		P="\033[1;95m"
		W="\033[1;97m"
		RES="\033[0m"
		print R"+"C"--------"R"+"C"----------"R"+"C"-------"R"+"C"-------"R"+"C"-----------------------------------------------------------"R"+"RES
		print R"| "W"DONE   "R"| "G"HAVE     "R"| "P"DOWN  "R"| "Y"ETA   "R"| "W"NAME                                                      "R"|"RES
		print R"+"C"--------"R"+"C"----------"R"+"C"-------"R"+"C"-------"R"+"C"-----------------------------------------------------------"R"+"RES
		}
		/^  Name/ {
		title = $2
		}
		/^  Percent Done/ {
		sub(/%$/, "", $2)
		done = sprintf("%.1f%%", $2)
		}
		/^  ETA/ {
		sub(/.*\(/, "", $2)
		sub(/ seconds\)/, "", $2)
		eta = int($2 / 60)
		}
		/^  Download Speed/ {
		speed = $2
		sub(/ .*/, "", speed)
		}
		/^  Have/ {
		sub(/ \(.*\)/, "", $2)
		sub(/ /, "", $2)
		have = $2
		}
		/^LIMITS & BANDWIDTH/ {
		if (done == "100.0%") {
			speed = "Done"
			eta = "Done"
		}
		printf R"| "W"%-6s "R"| "G"%-8s "R"| "P"%-5s "R"| "Y"%-5s "R"| "W"%-57s "R"|\n"RES, done, have, speed, eta, substr(title, 1, 57)
		print R"+"C"--------"R"+"C"----------"R"+"C"-------"R"+"C"-------"R"+"C"-----------------------------------------------------------"R"+"RES
		}
		'
        footclient -a torrent-float zsh -c 'while true; do tput cup 0 0; transmission-remote -t all -i | awk '"'${awk_script}'"'; sleep 0.1; done'
}

C="$(printf "List\0icon\037text-x-generic\nAdd\0icon\037list-add\nRemove\0icon\037user-trash\nTorrent Prio\0icon\037preferences-system\nFile Prio\0icon\037application-x-bittorrent\nStart/Stop\0icon\037media-playback-paused\nDisable All Files\0icon\037media-playback-stopped\nSearch\0icon\037system-search\nKillall\0icon\037system-shutdown\nDaemon\0icon\037transmission" | m "Torrents")"

case "${C}" in
        "Add") add ;;
        "Remove") remove ;;
        "List") list ;;
        "Torrent Prio") tor_prio ;;
        "File Prio") file_prio ;;
        "Start/Stop") start_stop ;;
        "Disable All Files") no_download ;;
        "Search") search ;;
        "Killall") killsv ;;
        "Daemon") transmission-daemon && n "Transmission ready" ;;
        *) exit ;;
esac
