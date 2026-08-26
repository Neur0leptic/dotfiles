#!/bin/dash

# Define directories and files
DATA_DIR="${HOME}/.cache/scientific_papers"
DOWNLOAD_DIR="${HOME}/scientific_papers"
LAST_CHECK_FILE="${DATA_DIR}/last_check"
TMP_FILE="${DATA_DIR}/rss_$$"

mkdir -p "${DATA_DIR}" "${DOWNLOAD_DIR}"

# RSS feed URLs
RSS_FEEDS="https://jamanetwork.com/rss/site_16/67.xml
https://www.nimh.nih.gov/rss/news-and-events.xml"

notify() {
    notify-send "Scientific Papers" "${1}"
}

DMENU() {
    rofi -dmenu -i -no-fixed-num-lines -p "${2}"
}

get_rss_feed() {
    for RSS_URL in $RSS_FEEDS; do
        curl -s "$RSS_URL"
    done
}

check_new_papers() {
    NEW_PAPERS=""

    # Fetch RSS feeds and parse with explicit delimiter
    get_rss_feed | xmlstarlet sel -t -m "//item" -v "title" -o "|||" -v "link" -n > "$TMP_FILE"

    while IFS= read -r line; do
        TITLE="${line%%|||*}"
        LINK="${line#*|||}"

        [ -z "$LINK" ] && continue

        if ! grep -qF "$LINK" "$LAST_CHECK_FILE" 2>/dev/null; then
            NEW_PAPERS="${NEW_PAPERS}${TITLE}|||${LINK}\n"
            echo "$LINK" >> "$LAST_CHECK_FILE"
        fi
    done < "$TMP_FILE"

    rm -f "$TMP_FILE"

    if [ -n "$NEW_PAPERS" ]; then
        notify "New papers found!"
        selection="$(printf '%b' "$NEW_PAPERS" | DMENU "20" "Select Paper to Read")"
        [ -n "$selection" ] && read_selected_paper "$selection"
    else
        notify "No new papers."
    fi
}

read_selected_paper() {
    selection="${1}"
    TITLE="${selection%%|||*}"
    LINK="${selection#*|||}"

    [ -z "$LINK" ] && return

    CHOICE="$(printf "READ\nDOWNLOAD\n" | DMENU "2" "Action for selected paper")"

    case "$CHOICE" in
        "READ")
            if [ -n "${BROWSER}" ]; then
                nohup "${BROWSER}" "$LINK" >/dev/null 2>&1 &
            else
                nohup xdg-open "$LINK" >/dev/null 2>&1 &
            fi
            ;;
        "DOWNLOAD")
            FILENAME="${DOWNLOAD_DIR}/${TITLE}.pdf"
            curl -L -o "$FILENAME" "$LINK"
            notify "Downloaded ${TITLE}"
            ;;
    esac
}

# Ensure the last check file exists
touch "$LAST_CHECK_FILE" 2>/dev/null

# Run the check for new papers
check_new_papers
