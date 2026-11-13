#!/bin/sh
# Shows the window that Super+Tab focused, with its icon, in the middle of the screen.
# Hyprland (binds.lua) and DWL (config.h) run it as:
#   window_notify.sh WORKSPACE OUTPUT APP_ID PID TITLE
# Look, timeout and silence come from the [app-name=Window] sections of ~/.config/mako/config.

[ "$#" -ge 4 ] || exit 2
ws=$1 output=$2 app=$3 pid=$4
shift 4
# The title stays in "$1" and is never copied: the Omen's dash would damage some UTF-8 letters.

theme=candy-icons
dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Icon= line of a desktop file
file_icon() {
	while IFS= read -r line; do
		case $line in Icon=*) icon=${line#Icon=}; return 0 ;; esac
	done <"$1"
	return 1
}

# Icon of the desktop entry named $1, in the XDG data directories
entry_icon() {
	IFS=:
	for d in $dirs; do
		if [ -r "$d/applications/$1.desktop" ] && file_icon "$d/applications/$1.desktop"; then
			unset IFS
			return 0
		fi
	done
	unset IFS
	return 1
}

# File of the icon named $1: the icon theme first, then hicolor and pixmaps
# (mako finds no names in scalable or theme directories by itself)
icon_file() {
	case $1 in
	/*) [ -r "$1" ] && path=$1 ;;
	?*)
		IFS=:
		for d in $dirs; do
			for f in "$d/icons/$theme/apps/scalable/$1.svg" "$d/icons/hicolor/scalable/apps/$1.svg" \
				"$d/icons/hicolor/256x256/apps/$1.png" "$d/icons/hicolor/128x128/apps/$1.png" \
				"$d/icons/hicolor/64x64/apps/$1.png" "$d/icons/hicolor/48x48/apps/$1.png" \
				"$d/pixmaps/$1.svg" "$d/pixmaps/$1.png"; do
				[ -r "$f" ] && path=$f && break 2
			done
		done
		unset IFS
		;;
	esac
	[ -n "$path" ]
}

# Desktop entry named like the app_id, like a webapp's entry (app_id WebApp-NAME) or like the
# process (foot windows with their own app_id), then the entry whose StartupWMClass matches.
# Without an entry, an icon named like the app_id or the process.
comm=
[ -r "/proc/$pid/comm" ] && read -r comm <"/proc/$pid/comm"
icon= path=
for id in "$app" "${app#WebApp-}" "$comm"; do
	[ -n "$id" ] && entry_icon "$id" && break
done
if [ -z "$icon" ] && [ -n "$app" ]; then
	file=$(IFS=:; for d in $dirs; do grep -l -s -x -F "StartupWMClass=$app" "$d"/applications/*.desktop; done | head -n 1)
	[ -n "$file" ] && file_icon "$file"
fi
icon_file "$icon" || icon_file "$app" || icon_file "$comm"

# The output travels as the category, and mako's [app-name=Window category=OUTPUT] sections
# show the notification there. Each output replaces only its own notification: mako 1.11
# does not redraw an output whose notification was replaced by one on another output.
[ -n "$1" ] || set -- "$app"
exec notify-send -a Window -c "$output" -i "$path" \
	-h "string:x-canonical-private-synchronous:window-$output" -- "$1" "Workspace $ws"
