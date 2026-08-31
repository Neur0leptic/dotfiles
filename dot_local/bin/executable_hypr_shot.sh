#!/bin/sh

mode="${1:-region}"

case "$mode" in
        region)
                geo="$(slurp)"
                sleep 0.2
                grim -t ppm -g "${geo}" - | satty --filename -
                ;;

        full)
                grim -t ppm - | satty --filename -
                ;;

        window)
		if [ -n "${DWL_SESSION:-}" ]; then
			IFS= read -r _pid || true
			IFS= read -r geo || true
		elif [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
			geo=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
		else
			printf 'cannot determine the active compositor\n' >&2
			exit 1
		fi
		[ -n "$geo" ] || exit 1
		sleep 0.2
		grim -t ppm -g "$geo" - | satty --filename -
		;;

        output)
		if [ -n "${DWL_SESSION:-}" ]; then
			output=$(slurp -o -f '%o')
		elif [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
			output=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
		else
			printf 'cannot determine the active compositor\n' >&2
			exit 1
		fi
		[ -n "$output" ] || exit 1
		grim -t ppm -o "$output" - | satty --filename -
                ;;

        *)
                echo "Usage: hypr_shot.sh [region|full|window|output]"
                exit 1
                ;;
esac
