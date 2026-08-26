#!/bin/bash

SCRIPT_DIR="$HOME/.local/bin/yourpipe"
source "${SCRIPT_DIR}/core/config.sh"
source "${SCRIPT_DIR}/lib/notify.sh"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/tsv.sh"
source "${SCRIPT_DIR}/core/common.sh"
source "${SCRIPT_DIR}/modules/fetch.sh"
source "${SCRIPT_DIR}/modules/play.sh"
source "${SCRIPT_DIR}/modules/browse.sh"
source "${SCRIPT_DIR}/modules/manage.sh"
source "${SCRIPT_DIR}/modules/lists.sh"
source "${SCRIPT_DIR}/modules/history.sh"

clip=$(wl-paste 2>/dev/null)
[ -z "$clip" ] && notify-send "ytopen" "Clipboard empty" && exit 1

case "$clip" in
    *youtube.com/watch*|*youtu.be/*|*youtube.com/shorts/*|*youtube.com/live/*|*m.youtube.com/*)
        video_id=$(echo "$clip" | sed 's/.*v=//; s/&.*//; s/.*youtu.be\///; s/\?.*//')
        video_id=$(echo "$video_id" | sed 's/[^a-zA-Z0-9_-].*//')
        if [ -n "$video_id" ]; then
            notify-send "ytopen" "Starting playback..."
            json=$(rustypipe get "$video_id" --format json 2>/dev/null)
            title=$(echo "$json" | jq -r '.name // "Clipboard"')
            channel_name=$(echo "$json" | jq -r '.channel.name // ""')
            channel_id=$(echo "$json" | jq -r '.channel.id // ""')
            views=$(echo "$json" | jq -r '.view_count // 0')
            duration=$(echo "$json" | jq -r '.duration // 0')
            date=$(echo "$json" | jq -r '.publish_date // ""' | sed 's/T.*//; s/-//g')
            TAB=$'\t'
            full_line="${title}${TAB}${video_id}${TAB}VIDEO${TAB}${channel_name}${TAB}${views}${TAB}${duration}${TAB}${date}${TAB}${channel_id}${TAB}false"
            play_video "$video_id" "$title" "$channel_name" "$full_line"
            video_action_menu "$video_id" "$title" "$channel_name" "$channel_id" "$full_line"
        else
            notify-send "ytopen" "Bad video ID"
        fi
        ;;
    *)
        notify-send "ytopen" "Not a YouTube link"
        ;;
esac
