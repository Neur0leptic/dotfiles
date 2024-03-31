#!/bin/sh

notify() {
	notify-send "Transmission" "${1}"
}

DMENU() {
        bemenu -i -l "${1}" -p "${2}"
}

find_id() {
	OPTIONS="$(transmission-remote -l | sed -E '1d;$d; s/^ *([0-9]+).*\s{2,}(.+)$/\1 \2/')"
	ID="$(echo "${OPTIONS}" | DMENU "10" "Select Torrent" | cut -d ' ' -f1)"
}

add_torrent() {
	MAGNET="$(wl-paste)"

	echo "${MAGNET}" | grep -qE '^[0-9a-fA-F]{40}$' && {
		MAGNET="magnet:?xt=urn:btih:${MAGNET}"
	} || {
		echo "${MAGNET}" | grep -qE '^magnet:\?xt=urn:btih:[0-9a-fA-F]{40}' || {
			notify "Clipboard not valid"
			exit
		}
	}

	while read -r tracker; do
		MAGNET="${MAGNET}&tr=${tracker}"
	done < "${XDG_DATA_HOME}/encoded_trackers.txt"

	pidof transmission-daemon > "/dev/null" || { transmission-daemon; sleep "3"; }
	transmission-remote -a "${MAGNET}" &&

	HASH="${MAGNET#*btih:}"; HASH="${HASH%%&*}"
	notify "\"${HASH}\" added."
}

remove_torrent() {
	find_id
	transmission-remote -t "${ID}" -r && notify "\"${ID}\" removed"
}

list_torrents() {
	foot bash -c 'transmission-remote -l; read -r -p "Press enter to quit..."'
}

ch_torrent_prio() {
	find_id

	PRIORITY="$(printf "High\nNormal\nLow" | DMENU "3" "Select Priority")"

	case "${PRIORITY}" in
		"High") transmission-remote -t "${ID}" -Bh ;;
		"Normal") transmission-remote -t "${ID}" -Bn ;;
		"Low") transmission-remote -t "${ID}" -Bl ;;
		*) exit ;;
	esac && notify "\"${ID}\" priority set to ${PRIORITY}."
}

ch_file_prio() {
    	find_id

	foot bash -c "transmission-remote -t \"${ID}\" -f |
		sed -E '1,2d; s/^[ ]*([0-9]+):[ ]+([^ ]+ +){3}([^ ]+ [^ ]+)[ ]+(.*)/\1 \3 \4/' |
		fzf -m | cut -d ' ' -f 1 > /tmp/selected_files"

	SELECTED_FILES="$(cat "/tmp/selected_files")"

	PRIORITY="$(printf "High\nNormal\nLow\nNo Download" | DMENU "4" "Priority")"

	for FILE_INDEX in ${SELECTED_FILES}; do
		FILE_INDEX_LIST="${FILE_INDEX_LIST}${FILE_INDEX},"
	done

	FILE_INDEX_LIST=${FILE_INDEX_LIST%,}

	case "${PRIORITY}" in
		"High") CMD_ARGS="-g ${FILE_INDEX_LIST} -ph ${FILE_INDEX_LIST}" ;;
		"Normal") CMD_ARGS="-g ${FILE_INDEX_LIST} -pn ${FILE_INDEX_LIST}" ;;
		"Low") CMD_ARGS="-g ${FILE_INDEX_LIST} -pl ${FILE_INDEX_LIST}" ;;
		"No Download") CMD_ARGS="-G ${FILE_INDEX_LIST} -pl ${FILE_INDEX_LIST}" ;;
		*) exit ;;
	esac

	transmission-remote -t "${ID}" ${CMD_ARGS}
	notify "Prio ${PRIORITY}: ${FILE_INDEX_LIST}"

	rm -f "/tmp/selected_files"
}

start_stop() {
	find_id

	CHOICE="$(printf "Start\nStop" | DMENU "2" "Action for torrent ${ID}")"

	case "${CHOICE}" in
		"Start") transmission-remote -t "${ID}" --start && notify "${ID} started" ;;
		"Stop") transmission-remote -t "${ID}" --stop && notify "${ID} stopped" ;;
		*) exit ;;
	esac
}

no_download() {
	find_id
	transmission-remote -t "${ID}" -G "all"
}

install_services() {
	notify "Installing Prowlarr & Flaresolverr..."
	notify "This can take a while..."

	command -v "emerge" > "/dev/null" && {
		{
			echo '# Needed for flaresolver'
			echo 'x11-base/xorg-server xvfb minimal'
		} >> /etc/portage/package.use

		emerge --info "x11-base/xorg-server" > "/dev/null" || doas emerge --ask=no "x11-base/xorg-server"

	} || sudo pacman -S "xorg-server-xvfb"

	flare_url="$(curl -s "https://api.github.com/repos/FlareSolverr/FlareSolverr/releases/latest" |
		grep -oP '"browser_download_url": "\K(.*linux_x64.tar.gz)(?=")')"

	prowlarr_url="$(curl -s "https://api.github.com/repos/Prowlarr/Prowlarr/releases/latest" |
		grep -oP '"browser_download_url": "\K(.*linux-core-x64.tar.gz)(?=")')"

	mkdir -p "${HOME}/.local/src"

	curl -L "${flare_url}" | tar -xz -C "${HOME}/.local/src"
	mv "${HOME}/.local/src"/*linux_x64 "${HOME}/.local/src/flaresolverr"

	curl -L "${prowlarr_url}" | tar -xz -C "${HOME}/.local/src"
	mv "${HOME}/.local/src"/Prowlarr* "${HOME}/.local/src/prowlarr"

	notify "Installation finished successfully"
	notify "You can run the script again"
	exit
}

search_torrents() {
	[ -f "${HOME}/.local/src/prowlarr/Prowlarr" ] || {
		SELECTION="$(printf "No\nYes" | DMENU "2" "You want to install Prowlarr & Flaresolverr?")"

		[ "${SELECTION}" = "Yes" ] && install_services || exit
	}

	QUERY="$(echo "" | DMENU "0" "Torrent Search Query")"

	pidof flaresolverr || {
		notify "Starting Flaresolverr..."
		"${HOME}/.local/src/flaresolverr/flaresolverr" &
	}

	pidof Prowlarr || {
		notify "Starting Prowlarr..."
		"${HOME}/.local/src/prowlarr/Prowlarr" &
	}

	i="0"
	while [ "${i}" -lt "15" ]; do
		curl -s "http://localhost:9696" > "/dev/null" &&
		curl -s "http://0.0.0.0:8191" > "/dev/null" && break
		i="$((i + 1))"
		sleep "0.5"
	done

	[ "${i}" -lt "15" ] || notify "A service did not start. Check dependencies."

	notify "Prowlarr & Flaresolver ready"

	"${BROWSER}" "http://localhost:9696/search?query=${QUERY}"
}

exit_services() {
	while pidof -s Prowlarr flaresolverr transmission-daemon
		do killall Prowlarr flaresolverr transmission-daemon
	done
	notify "Services are closed"
}

main() {
    	CHOICE="$(printf "Add Torrent\nRemove Torrent\nList Torrents\nChange Torrent Priority\nChange File Priority\nStart/Stop\nDisable All Files\nSearch Torrents\nExit Services" | DMENU "9" "Transmission")"

    	case "${CHOICE}" in
        	"Add Torrent") add_torrent ;;
        	"Remove Torrent") remove_torrent ;;
        	"List Torrents") list_torrents ;;
        	"Change Torrent Priority") ch_torrent_prio ;;
        	"Change File Priority") ch_file_prio ;;
		"Start/Stop") start_stop ;;
		"Disable All Files") no_download ;;
		"Search Torrents") search_torrents ;;
		"Exit Services") exit_services ;;
		*) exit ;;
	esac
}

main
