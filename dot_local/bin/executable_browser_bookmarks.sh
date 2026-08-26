#!/bin/dash

URLQUERY_FILE="${HOME}/.local/share/urlquery"
ACTION_MENU="@@"

CLIPBOARD() {
        wl-paste
}

DMENU() {
        tmp="/tmp/rofi_bm_$$"
        cat > "$tmp"

        x=$(awk -F'\0' '{print length($1)}' "$tmp" | sort -rn | head -1)
        [ -z "$x" ] && x=10

        chk=$(printf '%s' "${2}" | awk '{print length($0)}')
        [ "$x" -lt "$chk" ] && x="$chk"

        x=$((x + 15))

        [ "$x" -lt 30 ] && x=30
        [ "$x" -gt 150 ] && x=150

        cat "$tmp" | rofi -dmenu -i -show-icons -p "${2}" -theme-str "window { width: ${x}ch; }"
        rm -f "$tmp"
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
                printf "SearXNG=http://127.0.0.1:8888/search?q=\n" > "${URLQUERY_FILE}"
        }
}

resolve_icon_path() {
        _icon_name="$1"
        _icons_candy="${XDG_DATA_HOME:-${HOME}/.local/share}/icons/candy-icons"
        _icons_local="${HOME}/.local/share/applications/icons"

        [ -f "${_icons_candy}/${_icon_name}" ] && printf '%s' "${_icons_candy}/${_icon_name}" && return
        [ -f "${_icons_local}/${_icon_name}" ] && printf '%s' "${_icons_local}/${_icon_name}" && return

        _basename="${_icon_name##*/}"
        find "$_icons_candy" "$_icons_local" -type f -name "$_basename" -print -quit 2>/dev/null
}

get_selection() {
        while IFS='=' read -r name rest; do
                icon_name=""
                case "$rest" in
                        *\|icon:*)
                                icon_name="${rest##*|icon:}"
                                rest="${rest%|icon:*}"
                                ;;
                esac

                if [ -n "$icon_name" ]; then
                        icon_path="$(resolve_icon_path "$icon_name")"
                        if [ -n "$icon_path" ]; then
                                printf "%s\0icon\037%s\n" "${name}" "${icon_path}"
                        else
                                printf "%s\0icon\037%s\n" "${name}" "internet-web-browser"
                        fi
                else
                        icon="internet-web-browser"
                        case "${rest}" in
                                *search*|*wiki*) icon="system-search" ;;
                                *packages*|*aur*) icon="system-software-install" ;;
                        esac
                        printf "%s\0icon\037%s\n" "${name}" "${icon}"
                fi
        done < "${URLQUERY_FILE}" | DMENU "${LINE_COUNT}" "Bookmarks"
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

select_icon() {
        icons_candy="${XDG_DATA_HOME:-${HOME}/.local/share}/icons/candy-icons"
        icons_local="${HOME}/.local/share/applications/icons"

        [ -d "$icons_candy" ] || [ -d "$icons_local" ] || return 1

        {
                [ -d "$icons_candy" ] && find "$icons_candy" -type f \( -name "*.svg" -o -name "*.png" \) 2>/dev/null
                [ -d "$icons_local" ] && find "$icons_local" -type f \( -name "*.svg" -o -name "*.png" \) 2>/dev/null
        } | sort -u |
                while IFS= read -r icon_path; do
                        case "$icon_path" in
                                $icons_candy/*) rel_path="${icon_path#$icons_candy/}" ;;
                                $icons_local/*) rel_path="${icon_path#$icons_local/}" ;;
                                *) rel_path="${icon_path##*/}" ;;
                        esac
                        printf '%s\0icon\x1f%s\n' "${rel_path}" "$icon_path"
                done |
                rofi -dmenu -i -no-fixed-num-lines -show-icons -p "Select Icon" -format 's'
}

add_bookmark() {
        URL="$(CLIPBOARD)"

        is_valid_url "${URL}" || error_notify "The clipboard content is not a valid URL."

        esc_url="$(printf "%s\n" "${URL}" | sed 's/[][\.*^$+?{|()]/\\&/g')"
        grep -qE "^[^=]*=${esc_url}(\|icon:.*)?$" "${URLQUERY_FILE}" &&
                notify "The URL is already in the list." && return

        NAME="$(printf "" | DMENU "0" "Name")"
        [ -z "${NAME}" ] && return

        ICON="$(select_icon)"

        if [ -n "${ICON}" ]; then
                printf "%s\n" "${NAME}=${URL}|icon:${ICON}" >> "${URLQUERY_FILE}"
        else
                printf "%s\n" "${NAME}=${URL}" >> "${URLQUERY_FILE}"
        fi
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
        LINE="$(grep "^${NAME}=" "${URLQUERY_FILE}")"
        REST="${LINE#*=}"

        icon_suffix=""
        case "$REST" in
                *\|icon:*)
                        icon_suffix="|icon:${REST##*|icon:}"
                        ;;
        esac

        NEW_URL="$(echo "" | DMENU "0" "New URL")"
        [ -z "${NEW_URL}" ] && return

        update_file "^${NAME}=.*" "${NAME}=${NEW_URL}${icon_suffix}"
}

edit_icon() {
        NAME="${1}"
        LINE="$(grep "^${NAME}=" "${URLQUERY_FILE}")"
        REST="${LINE#*=}"
        URL="${REST%|icon:*}"

        ICON="$(select_icon)"
        [ -z "${ICON}" ] && return

        update_file "^${NAME}=.*" "${NAME}=${URL}|icon:${ICON}"
}

edit_bookmark() {
        NAME="$(get_selection)"

        [ -z "${NAME}" ] && error_notify "Failed to edit the bookmark."

        FIELD="$(printf "Name\0icon\037user-bookmarks\nURL\0icon\037internet-web-browser\nIcon\0icon\037preferences-desktop-icons\n" | DMENU "3" "Edit")"

        case "${FIELD}" in
                "Name") edit_name "${NAME}" ;;
                "URL") edit_url "${NAME}" ;;
                "Icon") edit_icon "${NAME}" ;;
        esac

        notify "'${NAME}' is updated."
}

open_bookmark() {
        URL="$(grep "^${SELECTION}=" "${URLQUERY_FILE}" | cut -d= -f2-)"
        URL="${URL%|icon:*}"

        [ -z "${URL}" ] && error_notify "Bookmark not found."

        case "${URL}" in
                *"search"* | *"wiki"* | *"packages"*)
                        QUERY="$(echo "" | DMENU "0" "Search")"
                        URL="${URL}${QUERY}"
                        ;;
        esac

        nohup "${BROWSER}" "${URL}" >/dev/null 2>&1 &
}

ensure_file_exists

LINE_COUNT="$(wc -l < "${URLQUERY_FILE}")"

[ "${LINE_COUNT}" -ge "15" ] && LINE_COUNT="15"

SELECTION="$(get_selection)"

[ -z "${SELECTION}" ] && exit

case "${SELECTION}" in
        "${ACTION_MENU}")
                ACTION="$(printf "Add\0icon\037list-add\nDelete\0icon\037user-trash\nEdit\0icon\037accessories-text-editor\n" | DMENU "3" "Action")"

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
