#!/bin/dash

bin_dir="${HOME}/.local/bin"

selection=$(
	for path in "${bin_dir}"/*; do
		[ -f "${path}" ] && [ -x "${path}" ] || continue
		printf '%s\n' "${path##*/}"
	done | rofi -dmenu -i -no-custom -no-show-icons -matching fuzzy \
		-p "Scripts" \
		-mesg "Enter/click: run    Shift+Enter: run and hold" \
		-kb-accept-alt "" -kb-custom-1 "Shift+Return" \
		-theme-str "window { width: 47ch; } mainbox { children: [ inputbar, listview, message ]; } message { background-color: @BG; text-color: @FG; } textbox { background-color: inherit; text-color: inherit; horizontal-align: 0.5; }"
)
rofi_status=$?

case "${rofi_status}" in
	0) hold=false ;;
	10) hold=true ;;
	*) exit 0 ;;
esac

[ -n "${selection}" ] || exit 0
script="${bin_dir}/${selection}"
[ -f "${script}" ] && [ -x "${script}" ] || exit 1

if [ "${hold}" = true ]; then
	exec footclient -a floating --window-size-chars=100x30 --working-directory="${HOME}" \
		sh -c '
			"$1"
			status=$?
			printf "\nExited with status %s. Press Enter to close..." "$status"
			read -r _
			exit "$status"
		' sh "${script}"
fi

exec footclient -a floating --window-size-chars=100x30 --working-directory="${HOME}" \
	sh -c '
		"$1"
		status=$?
		if [ "$status" -ne 0 ]; then
			printf "\nFailed with status %s. Press Enter to close..." "$status"
			read -r _
		fi
		exit "$status"
	' sh "${script}"
