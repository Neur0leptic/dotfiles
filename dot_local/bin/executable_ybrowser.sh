#!/bin/dash

DATA_DIR="${HOME}/.cache/youtube_channels"
DOWNLOAD_DIR="${HOME}/ytvideos"
CATEGORY_LIST="${HOME}/.local/share/categories.txt"
CHANNEL_LIST="${HOME}/.local/share/channels.txt"
CUSTOM_LIST_DIR="${DATA_DIR}/custom_lists"

mkdir -p "${DATA_DIR}" "${DOWNLOAD_DIR}" "${CUSTOM_LIST_DIR}"

DMENU() {
        rofi -dmenu -i -no-fixed-num-lines -p "${1}"
}

sort_videos() {
        data_file="${1}"
        sort_option="${2}"

        case "${sort_option}" in
                "@@sv") sort -nr -t"	" -k3 "${data_file}" ;;
                "@@sd") sort -nr -t"	" -k4 "${data_file}" ;;
                *) sort -nr -t"	" -k5 "${data_file}" ;;
        esac | hck -d '\t' -f1
}

get_videos() {
        channel_name="${1}"
        sort_option="${2}"
        data_file="${DATA_DIR}/${channel_name}.tsv"
        sort_videos "${data_file}" "${sort_option}"
}

video_url() {
        channel_name="${1}"
        video_title="${2}"
        data_file="${DATA_DIR}/${channel_name}.tsv"

        rg -F "${video_title}" "${data_file}" | hck -d '\t' -f2
}

menu_action() {
        printf "WATCH\nDOWNLOAD\nSEND TO A LIST\n" | DMENU "Choose an action for the video"
}

menu_custom_list_action() {
        printf "%s\n" "$(fd -t "f" -d "1" . "${CUSTOM_LIST_DIR}" -X basename)
#### CREATE A LIST ####
#### DELETE A LIST ####" | DMENU "Choose an action or list"
}

list_video_action() {
        printf "WATCH\nDOWNLOAD\nDELETE\n" | DMENU "Choose an action for the video"
}

add_to_list() {
        video_title="${1}"
        channel_name="${2}"
        list_name="${3}"
        printf "%s\n" "${channel_name}: ${video_title}" >> "${CUSTOM_LIST_DIR}/${list_name}"
}

custom_list_menu() {
        while true; do
                list="$(menu_custom_list_action)"
                [ -z "${list}" ] && return
                case "${list}" in
                        *CREATE*)
                                new_list="$(printf "" | DMENU "Enter the name of the new list")"
                                [ -n "${new_list}" ] && touch "${CUSTOM_LIST_DIR}/${new_list}"
                                ;;
                        *DELETE*)
                                delete_list="$(fd -t "f" -d "1" . "${CUSTOM_LIST_DIR}" -x basename |
                                        DMENU "Choose a list to delete")"
                                [ -n "${delete_list}" ] && rm -f "${CUSTOM_LIST_DIR}/${delete_list}"
                                ;;
                        *)
                                custom_list_video_menu "${list}"
                                ;;
                esac
        done
}

custom_list_video_menu() {
        list_name="${1}"
        while true; do
                video_info=$(DMENU "Choose a video" < "${CUSTOM_LIST_DIR}/${list_name}")
                [ -z "${video_info}" ] && return
                channel_name="${video_info%%: *}"
                video_title="${video_info##*: }"
                custom_list_video_action_menu "${video_title}" "${channel_name}" "${list_name}"
        done
}

custom_list_video_action_menu() {
        video_title="${1}"
        channel_name="${2}"
        list_name="${3}"

        action="$(list_video_action)"

        case "${action}" in
                WATCH)
                        video_process WATCH "${video_title}" "${channel_name}"
                        ;;
                DOWNLOAD)
                        video_process DOWNLOAD "${video_title}" "${channel_name}" &&
                                notify-send -i applications-multimedia "Downloading has finished."
                        ;;
                DELETE)
                        escaped_video_title="$(printf "%s\n" "${video_title}" | sd '[][\^$.\/|*+?(){}#]/\\&' '')"

                        sd ".*${escaped_video_title}.*\n" "" "${CUSTOM_LIST_DIR}/${list_name}"
                        ;;
                *)
                        return
                        ;;
        esac
}

video_process() {
        action="${1}"
        video_title="${2}"
        channel_name="${3}"
        video_url="$(video_url "${channel_name}" "${video_title}")"

        case "${action}" in
                WATCH)
                        mpv --ytdl-format="bestvideo[height<=1080]+bestaudio" "${video_url}"
                        ;;
                DOWNLOAD)
                        channel_download_dir="${DOWNLOAD_DIR}/${channel_name}"
                        mkdir -p "${channel_download_dir}"
                        yt-dlp -o "${channel_download_dir}/%(title)s.%(ext)s" "${video_url}"
                        notify-send -i applications-multimedia "Downloading has finished."
                        ;;
        esac
}

get_all_videos() {
        sort_option="${1}"
        all_videos_file="${DATA_DIR}/all_videos.tsv"

        rm -f "${all_videos_file}"
        while IFS= read -r "line"; do
                channel_name="${line%%=*}"
                cat "${DATA_DIR}/${channel_name}.tsv" >> "${all_videos_file}"
        done < "${CHANNEL_LIST}"

        sort_videos "${all_videos_file}" "${sort_option}"
}

browse_all_channels() {
        while video_title="$(get_all_videos | DMENU "Choose a video or enter @@sv or @@sd")"; do
                [ -z "${video_title}" ] && break
                [ "${video_title}" = "@@sv" ] || [ "${video_title}" = "@@sd" ] && {
                        video_title=$(get_all_videos "${video_title}" | DMENU "Choose a video")
                        [ -z "${video_title}" ] && continue
                }

                rg -lF "${video_title}" "${DATA_DIR}"/*.tsv | head -n "1" | while read -r "video_file"; do
                        video_action_menu "${video_title}" "$(basename "${video_file}" .tsv)"
                        break
                done
        done
}

category_menu() {
        while true; do
                category="$(hck -Ld '=' -f1 "${CATEGORY_LIST}" | DMENU "Choose a category")"
                [ -z "${category}" ] && return

                channel_menu "${category}"
        done
}
channel_menu() {
        category="${1}"
        IFS="|"

        channels="$(sed -n "s/^${category}=\(.*\)$/\1/p" "${CATEGORY_LIST}")"
        set -- ${channels}

        while true; do
                channel_name="$(printf "%s\n" "${@}" | DMENU "Choose a channel")"
                [ -z "${channel_name}" ] && return

                video_menu "${channel_name}"
        done
}

video_menu() {
        channel_name="${1}"

        while true; do
                video_title=$(get_videos "${channel_name}" | DMENU "Choose a video")
                [ -z "${video_title}" ] && return
                [ "${video_title}" = "@@sv" ] || [ "${video_title}" = "@@sd" ] && {
                        sort_option="${video_title}"
                        video_title="$(get_videos "${channel_name}" "${sort_option}" | DMENU "Choose a video")"
                }

                video_action_menu "${video_title}" "${channel_name}"
        done
}

video_action_menu() {
        video_title="${1}"
        channel_name="${2}"

        while [ -n "${video_title}" ] && [ "${video_title}" != "@@sv" ] && [ "${video_title}" != "@@sd" ]; do
                action="$(menu_action)"

                case "${action}" in
                        WATCH)
                                video_process WATCH "${video_title}" "${channel_name}"
                                ;;
                        DOWNLOAD)
                                video_process DOWNLOAD "${video_title}" "${channel_name}" &&
                                        notify-send -i applications-multimedia \
                                                "Downloading has finished."
                                ;;
                        "SEND TO A LIST")
                                list_name="$(fd -t "f" -d "1" . "${CUSTOM_LIST_DIR}" -x basename |
                                        DMENU "Choose a list")"

                                [ -n "${list_name}" ] && add_to_list "${video_title}" "${channel_name}" "${list_name}" &&
                                        notify-send -i applications-multimedia \
                                                "${video_title} is added to the list: ${list_name}"
                                ;;
                        *)
                                return
                                ;;
                esac
        done
}

main_menu() {
        options="    ALL CHANNELS
 󰵀  CATEGORIES
   CUSTOM LISTS
$(hck -Ld "=" -f1 "${CHANNEL_LIST}")"

        printf "%s\n" "${options}" | DMENU "Choose an Option or a Category"
}

while true; do

        main_choice="$(main_menu)"

        [ -z "${main_choice}" ] && exit

        case "${main_choice}" in
                *"ALL CHANNELS"*) browse_all_channels ;;
                *"CATEGORIES"*) category_menu ;;
                *"CUSTOM LISTS"*) custom_list_menu ;;
                *) video_menu "${main_choice}" ;;
        esac
done
