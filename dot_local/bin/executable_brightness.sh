#!/bin/sh
# Screen brightness on a perceptual curve (exponent 2) for the keys, Waybar and the login
# level: 5% steps above 10%, 1% steps from 10% down to 0 (backlight off). Every step
# changes the panel; on a backlight with few levels it moves on to the next level that
# does. Without an argument it only shows the current level.

usage() {
        echo "Usage: brightness.sh [up|down|set PERCENT]" >&2
        exit 1
}

case "${1:-}" in
        up | down | "") ;;
        set) case "${2:-}" in '' | *[!0-9]*) usage ;; esac ;;
        *) usage ;;
esac

max="$(brightnessctl m)"
current="$(brightnessctl g)"

# Prints the new raw value and its percentage.
target="$(awk -v max="$max" -v raw="$current" -v how="${1:-}" -v percent="${2:-}" '
        function value(p) { return int(max * (p / 100) ^ 2 + 0.5) }
        BEGIN {
                new = raw
                if (how == "set") {
                        p = percent + 0
                        new = value(p < 0 ? 0 : p > 100 ? 100 : p)
                } else if (how == "up" || how == "down") {
                        p = int(100 * sqrt(raw / max) + 0.5)
                        do {
                                if (how == "up")
                                        p = p < 10 ? p + 1 : (int(p / 5) + 1) * 5
                                else
                                        p = p <= 10 ? p - 1 : (p % 5 ? int(p / 5) * 5 : p - 5)
                                p = p < 0 ? 0 : p > 100 ? 100 : p
                                new = value(p)
                        } while (how == "up" ? new <= raw && p < 100 : new >= raw && p > 0)
                }
                # Shown on the same steps: a backlight with few levels lands near them.
                shown = 100 * sqrt(new / max)
                printf "%d %d\n", new, shown < 9.5 ? int(shown + 0.5) : int(shown / 5 + 0.5) * 5
        }')"
new="${target% *}"
brightness="${target#* }"

[ "$new" = "$current" ] || brightnessctl -q set "$new"
[ "${1:-}" = set ] && exit 0

icon="${XDG_DATA_HOME:-${HOME}/.local/share}/icons/candy-icons/preferences/scalable/preferences-desktop-display.svg"

notify-send -h string:x-canonical-private-synchronous:brightness -a "Brightness" -i "$icon" -h "int:value:${brightness}" "Brightness  ${brightness}%" ""
