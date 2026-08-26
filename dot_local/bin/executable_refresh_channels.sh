#!/bin/dash

while ! ping -c 1 "9.9.9.9"; do sleep "0.5"; done

DATA_DIR="${HOME}/.cache/youtube_channels"
CHANNEL_LIST="${HOME}/.local/share/channels.txt"
mkdir -p "${DATA_DIR}" && touch "${CHANNEL_LIST}"

compare_data() {
        channel_name="${1}"
        data_file="${DATA_DIR}/${channel_name}.tsv"
        old_data_file="${DATA_DIR}/${channel_name}_old.tsv"

        [ -e "${old_data_file}" ] && {
                old_urls="$(cut -f2 "${old_data_file}")"
                new_urls="$(cut -f2 "${data_file}")"

                printf "%s\n" "${old_urls}" | sort > "temp1"
                printf "%s\n" "${new_urls}" | sort > "temp2"
                new_videos="$(comm -13 "temp1" "temp2" | wc -l)"
                rm -f "temp1" "temp2"

                [ "${new_videos}" -gt "0" ] &&
                        notify-send -i applications-multimedia -u "critical" \
                                "${channel_name} | ${new_videos} videos."
        }
}

update_data() {
        channel_name="${1}"
        channel_url="${2}"
        data_file="${DATA_DIR}/${channel_name}.tsv"
        old_data_file="${DATA_DIR}/${channel_name}_old.tsv"

        mv -f "${data_file}" "${old_data_file}" 2> "/dev/null"

        yt-dlp -j --flat-playlist --skip-download --extractor-args "youtubetab:approximate_date" "${channel_url}" |
                jq -r '[.title, .url, .view_count, .duration, .upload_date] | @tsv' > "${data_file}"
}

update_all_channels() {
        while IFS="=" read -r channel_name channel_url; do
                update_data "${channel_name}" "${channel_url}" &
        done < "${CHANNEL_LIST}"

        wait

        while IFS="=" read -r channel_name channel_url; do
                compare_data "${channel_name}"
        done < "${CHANNEL_LIST}"
}

update_all_channels
