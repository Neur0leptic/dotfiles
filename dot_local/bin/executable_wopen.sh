#!/bin/dash

BROWSER="librewolf"
SEARXNG="http://127.0.0.1:8888/search?q="

clip=$(wl-paste 2>/dev/null)
[ -z "$clip" ] && notify-send "wopen" "Clipboard empty" && exit 1

case "$clip" in
    *://*)
        nohup "$BROWSER" "$clip" >/dev/null 2>&1 &
        ;;
    *.*/*|*.*.?*)
        nohup "$BROWSER" "https://$clip" >/dev/null 2>&1 &
        ;;
    *)
        encoded=$(printf '%s' "$clip" | sed 's/%/%25/g; s/&/%26/g; s/#/%23/g; s/+/%2B/g' | tr ' ' '+')
        nohup "$BROWSER" "${SEARXNG}${encoded}" >/dev/null 2>&1 &
        ;;
esac

hyprctl dispatch 'hl.dsp.focus({ window = "class:^(librewolf)$" })' 2>/dev/null
