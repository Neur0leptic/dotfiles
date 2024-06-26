#!/bin/dash

URLQUERY_FILE="${HOME}/.local/share/urlquery"
ACTION_MENU="@@"

CLIPBOARD() {
	wl-paste
}

DMENU() {
	bemenu -i -l "${1}" -p "${2}"
}

notify() {
	notify-send "Bookmarks" "${1}"
}

error_notify() {
	notify-send "Bookmarks" "${1}"
	exit "1"
}

ensure_file_exists() {
	[ -f "${URLQUERY_FILE}" ] || {
		notify "${URLQUERY_FILE} does not exist. Creating it now."
		printf "SearXNG=https://searx.tiekoetter.com/search?q=\n" > "${URLQUERY_FILE}"
	}
}

get_selection() {
	cut -d= -f1 "${URLQUERY_FILE}" | DMENU "${LINE_COUNT}" "Bookmarks"
}

update_file() {
	pattern="${1}"
	replacement="${2}"

	sed "/${pattern}/c\\${replacement}" "${URLQUERY_FILE}" > "${URLQUERY_FILE}.tmp" &&
			mv "${URLQUERY_FILE}.tmp" "${URLQUERY_FILE}" ||
				error_notify "Failed to update the file."
}

is_valid_url() {
	printf "%s\n" "${1}" | grep -qE "^https?://[^[:space:]/?#][^[:space:]]+$"
}

add_bookmark() {
	URL="$(CLIPBOARD)"

	is_valid_url "${URL}" || error_notify "The clipboard content is not a valid URL."

	grep -q "=${URL}$" "${URLQUERY_FILE}" &&
		notify "The URL is already in the list." && return

	NAME="$(printf "" | DMENU "0" "Name")"

	[ -n "${NAME}" ] && printf "%s\n" "${NAME}=${URL}" >> "${URLQUERY_FILE}" &&
		notify "'${NAME}' is bookmarked."
}

delete_bookmark() {
	NAME="$(get_selection)"

	[ -z "${NAME}" ] && error_notify "Failed to delete the bookmark."

	sed "/^${NAME}=/d" "${URLQUERY_FILE}" > "${URLQUERY_FILE}.tmp"
	mv "${URLQUERY_FILE}.tmp" "${URLQUERY_FILE}"

	[ -s "${URLQUERY_FILE}" ] && grep -qE "\S" "${URLQUERY_FILE}" || rm "${URLQUERY_FILE}"

	notify "'${NAME}' is deleted."
}

edit_name() {
	OLD_NAME="${1}"
	NEW_NAME="$(printf "" | DMENU "0" "New Name")"

	[ -z "${NEW_NAME}" ] && return

	URL="$(grep "^${OLD_NAME}=" "${URLQUERY_FILE}" | cut -d= -f2)"

	update_file "^${OLD_NAME}=" "${NEW_NAME}=${URL}"
}

edit_url() {
	NAME="${1}"
	NEW_URL="$(echo "" | DMENU "0" "New URL")"

	[ -z "${NEW_URL}" ] && return

	update_file "^${NAME}=.*" "${NAME}=${NEW_URL}"
}

edit_bookmark() {
	NAME="$(get_selection)"

	[ -z "${NAME}" ] && error_notify "Failed to edit the bookmark."

	FIELD="$(printf "Name\nURL\n" | DMENU "2" "Edit")"

	case "${FIELD}" in
		"Name")edit_name "${NAME}";;
		"URL")edit_url "${NAME}"
	esac

	notify "'${NAME}' is updated."
}

open_bookmark() {
	URL="$(grep "^${SELECTION}=" "${URLQUERY_FILE}" | cut -d= -f2-)"

	[ -z "${URL}" ] && error_notify "Bookmark not found."

	case "${URL}" in
		*"search"* | *"wiki"* | *"packages"*) QUERY="$(echo "" | DMENU "0" "Search")"
		URL="${URL}${QUERY}"
		;;
	esac

	"${BROWSER}" "${URL}" || error_notify "Failed to open the URL: ${URL}"
}

ensure_file_exists

LINE_COUNT="$(wc -l < "${URLQUERY_FILE}")"

[ "${LINE_COUNT}" -ge "15" ] && LINE_COUNT="15"

SELECTION="$(get_selection)"

[ -z "${SELECTION}" ] && exit

case "${SELECTION}" in
        "${ACTION_MENU}")
                ACTION="$(printf "Add\nDelete\nEdit\n" | DMENU "3" "Action")"

		case "${ACTION}" in
                        "Add") add_bookmark ;;
                        "Delete") delete_bookmark ;;
                        "Edit") edit_bookmark ;;
                esac
                ;;
        *)
                open_bookmark
                ;;
esac
