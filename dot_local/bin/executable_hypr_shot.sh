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
                if ! command -v hyprctl > /dev/null 2>&1; then
                        echo "window mode requires hyprctl (Hyprland)" >&2
                        exit 1
                fi
                geo=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
                sleep 0.2
                grim -t ppm -g "$geo" - | satty --filename -
                ;;

        output)
                if ! command -v hyprctl > /dev/null 2>&1; then
                        echo "output mode requires hyprctl (Hyprland)" >&2
                        exit 1
                fi
                output=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
                grim -t ppm -o "$output" - | satty --filename -
                ;;

        *)
                echo "Usage: hypr_shot.sh [region|full|window|output]"
                exit 1
                ;;
esac
