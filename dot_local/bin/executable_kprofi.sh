#!/bin/bash
# KeePass frontend: rofi + nvim edit
# Depends: kp.py (pykeepass), rofi, gpg, wl-clipboard, notify-send, nvim, foot

umask 077

DB="${KPASS_DB:-${HOME}/keepass/passwords.kdbx}"
PASSFILE="${KPASS_PASSFILE:-${XDG_CONFIG_HOME:-${HOME}/.config}/keepass/pass.gpg}"
KP_BIN="${XDG_BIN_HOME:-${HOME}/.local/bin}/kp.py"

runtime_dir="${XDG_RUNTIME_DIR:-}"
temporary_runtime_dir=""
pass_tmp=""
entry_tmp=""
entry_orig=""

cleanup() {
	[ -z "${pass_tmp}" ] || rm -f -- "${pass_tmp}"
	[ -z "${entry_tmp}" ] || rm -f -- "${entry_tmp}"
	[ -z "${entry_orig}" ] || rm -f -- "${entry_orig}"
	[ -z "${temporary_runtime_dir}" ] || rm -rf -- "${temporary_runtime_dir}"
	unset PASS
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

fail() {
	notify-send "KeePass" "$1"
	exit 1
}

if [ -z "${runtime_dir}" ] || [ ! -d "${runtime_dir}" ] || [ ! -w "${runtime_dir}" ]; then
	temporary_runtime_dir=$(mktemp -d "${TMPDIR:-/tmp}/kprofi.XXXXXX") || fail "Could not create runtime directory"
	runtime_dir="${temporary_runtime_dir}"
fi

CACHE_FILE="${runtime_dir%/}/kprofi-entries"
CACHE_TTL=30

[ -f "${PASSFILE}" ] || fail "Missing ${PASSFILE}"
[ -f "${DB}" ] || fail "Missing ${DB}"
[ -x "${KP_BIN}" ] || fail "Missing ${KP_BIN}"

cache_entries() {
	if [ -f "${CACHE_FILE}" ] && [ $(( $(date +%s) - $(stat -c %Y "${CACHE_FILE}") )) -lt "${CACHE_TTL}" ]; then
		cat "${CACHE_FILE}"
	else
		kp ls | tee "${CACHE_FILE}"
	fi
}

PASS=$(timeout 0.3 gpg -d -q -- "${PASSFILE}" 2> /dev/null)
if [ -z "${PASS}" ]; then
	pass_tmp=$(mktemp "${runtime_dir%/}/kprofi-pass.XXXXXX") || fail "Could not create password buffer"
	footclient -a kprofi --window-size-chars=40x5 bash -c '
		umask 077
		gpg -d -q -- "$1" > "$2" 2>/dev/null
		status=$?
		printf "\nPress Enter to close..."
		read -r _
		exit "$status"
	' bash "${PASSFILE}" "${pass_tmp}"
	PASS=$(<"${pass_tmp}")
	rm -f -- "${pass_tmp}"
	pass_tmp=""
fi
[ -n "${PASS}" ] || fail "Failed to decrypt password"

kp() {
	KPASS_DB="${DB}" KPASS_PASSWORD="${PASS}" "${KP_BIN}" "$@"
}

edit_entry() {
	local entry="$1"
	entry_tmp=$(mktemp "${runtime_dir%/}/kprofi-entry.XXXXXX") || return
	entry_orig=$(mktemp "${runtime_dir%/}/kprofi-entry-original.XXXXXX") || return

	kp show "${entry}" > "${entry_tmp}" || return
	cp -- "${entry_tmp}" "${entry_orig}"
	footclient -a kprofi --window-size-chars=90x30 nvim -n \
		-c "setlocal ft=conf nobackup nowritebackup" "${entry_tmp}"
	if ! cmp -s "${entry_tmp}" "${entry_orig}"; then
		kp apply "${entry}" < "${entry_tmp}"
		notify-send "KeePass" "Updated: ${entry}"
		rm -f -- "${CACHE_FILE}"
	fi
	rm -f -- "${entry_tmp}" "${entry_orig}"
	entry_tmp=""
	entry_orig=""
}

action_menu() {
	local entry="$1"
	local details
	details=$(kp show "${entry}") || return
	local action
	action=$(printf "OK\0icon\x1fedit-copy\nEdit\0icon\x1faccessories-text-editor\nDelete\0icon\x1fuser-trash" | rofi -dmenu -show-icons -l 3 -p "${entry}" -mesg "${details}")
	case "${action}" in
		"Edit") edit_entry "${entry}" ;;
		"Delete")
			local confirm
			confirm=$(printf "Yes\0icon\x1fdialog-yes\nNo\0icon\x1fdialog-no" | rofi -dmenu -show-icons -l 2 -p "Delete ${entry}?")
			[ "${confirm}" = "Yes" ] && kp rm "${entry}" &&
				rm -f -- "${CACHE_FILE}" &&
				notify-send "KeePass" "Deleted: ${entry}"
			;;
	esac
}

main_choice=$(printf "Search\0icon\x1fsystem-search\nAdd\0icon\x1flist-add\nGenerate\0icon\x1fpreferences-system-power" | rofi -dmenu -show-icons -l 3 -p "KeePass")

[ -n "${main_choice}" ] || exit 0

case "${main_choice}" in
	"Search")
		entry=$(cache_entries | while IFS= read -r e; do printf "%s\0icon\x1fkeepassxc\n" "$e"; done | rofi -dmenu -show-icons -p "Entry")
		[ -n "${entry}" ] || exit 0

		kp pass "${entry}" | wl-copy
		notify-send "KeePass" "Password copied: ${entry}"
		action_menu "${entry}"
		;;
	"Add")
		title=$(rofi -dmenu -show-icons -p "Title")
		[ -n "${title}" ] || exit 0
		user=$(rofi -dmenu -show-icons -p "Username (optional)")
		url=$(rofi -dmenu -show-icons -p "URL (optional)")

		pw_choice=$(printf "Generate (24)\0icon\x1fpreferences-system-power\nGenerate (16)\0icon\x1fpreferences-system-power\nGenerate (32)\0icon\x1fpreferences-system-power\nGenerate (64)\0icon\x1fpreferences-system-power\nCustom length...\0icon\x1fpreferences-other\nType manually\0icon\x1faccessories-text-editor" | rofi -dmenu -show-icons -l 6 -p "Password")
		[ -n "${pw_choice}" ] || exit 0

		cmd_args=()
		[ -z "${user}" ] || cmd_args+=(-u "${user}")
		[ -z "${url}" ] || cmd_args+=(-l "${url}")

		case "${pw_choice}" in
			"Generate (24)")
				kp add "${title}" "${cmd_args[@]}" -g 24 &&
					kp pass "${title}" | wl-copy &&
					rm -f -- "${CACHE_FILE}" && notify-send "KeePass" "Created: ${title}" && action_menu "${title}"
				;;
			"Generate (16)")
				kp add "${title}" "${cmd_args[@]}" -g 16 &&
					kp pass "${title}" | wl-copy &&
					rm -f -- "${CACHE_FILE}" && notify-send "KeePass" "Created: ${title}" && action_menu "${title}"
				;;
			"Generate (32)")
				kp add "${title}" "${cmd_args[@]}" -g 32 &&
					kp pass "${title}" | wl-copy &&
					rm -f -- "${CACHE_FILE}" && notify-send "KeePass" "Created: ${title}" && action_menu "${title}"
				;;
			"Generate (64)")
				kp add "${title}" "${cmd_args[@]}" -g 64 &&
					kp pass "${title}" | wl-copy &&
					rm -f -- "${CACHE_FILE}" && notify-send "KeePass" "Created: ${title}" && action_menu "${title}"
				;;
			"Custom length...")
				len=$(rofi -dmenu -p "Length")
				[ -n "${len}" ] || exit 0
				kp add "${title}" "${cmd_args[@]}" -g "${len}" &&
					kp pass "${title}" | wl-copy &&
					rm -f -- "${CACHE_FILE}" && notify-send "KeePass" "Created: ${title}" && action_menu "${title}"
				;;
			"Type manually")
				manual=$(rofi -dmenu -p "Password")
				[ -n "${manual}" ] || exit 0
				kp add "${title}" "${cmd_args[@]}" -p "${manual}" &&
					wl-copy <<< "${manual}" &&
					rm -f -- "${CACHE_FILE}" && notify-send "KeePass" "Created: ${title}" && action_menu "${title}"
				;;
		esac
		;;
	"Generate")
		length=$(printf "24\0icon\x1fpreferences-system-power\n16\0icon\x1fpreferences-system-power\n32\0icon\x1fpreferences-system-power\n64\0icon\x1fpreferences-system-power\nCustom\0icon\x1fpreferences-other" | rofi -dmenu -show-icons -l 5 -p "Length")
		[ "${length}" = "Custom" ] && length=$(rofi -dmenu -p "Length (chars)")
		[ -n "${length}" ] || length=24
		pwgen=$(kp gen "${length}")
		printf '%s' "${pwgen}" | wl-copy
		notify-send "KeePass" "Generated ${length}-char password copied"
		printf '\nPassword: %s\n' "${pwgen}"
		read -r -p "Press Enter..."
		;;
esac
