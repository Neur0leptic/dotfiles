#!/bin/dash

[ -z "${1}" ] && printf 'Usage: %s <audio> <timecodes>\n' "$(basename "$0")" && exit 1
[ -f "${1}" ] || { printf 'Audio file not found: %s\n' "${1}"; exit 1; }
[ -f "${2}" ] || { printf 'Timecodes file not found: %s\n' "${2}"; exit 1; }

printf "Enter the album/book title:\n"
read -r "booktitle"
printf "Enter the artist/author:\n"
read -r "author"
printf "Enter the publication year:\n"
read -r "year"

inputaudio="${1}"
escbook="$(printf "%s\n" "${booktitle}" | iconv -cf UTF-8 -t ASCII//TRANSLIT |
	tr -d '[:punct:]' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' |
	sed "s/-\+/-/g;s/\(^-\|-\$\)//g")"

mkdir -p "${escbook}" || { printf 'Cannot create directory: %s\n' "${escbook}"; exit 1; }

total="$(wc -l < "${2}")"
track=1
start=""

while read -r x || [ -n "${x}" ]; do
	end="$(printf "%s\n" "${x}" | cut -d' ' -f1)"

	if [ -n "${start}" ]; then
		file="${escbook}/$(printf "%.2d" "${track}")-${esctitle}"
		ffmpeg -i "${inputaudio}" -nostdin -y -ss "${start}" -to "${end}" -vn -c:a libopus -b:a 96k "${file}.opus"
		tag.sh -a "${author}" -t "${title}" -A "${booktitle}" -n "${track}" -N "${total}" -d "${year}" "${file}.opus"
		track="$(( track + 1 ))"
	fi

	title="$(printf "%s\n" "${x}" | cut -d' ' -f2-)"
	esctitle="$(printf "%s\n" "${title}" | iconv -cf UTF-8 -t ASCII//TRANSLIT | tr -d '[:punct:]' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed "s/-\+/-/g;s/\(^-\|-\$\)//g")"
	start="${end}"
done < "${2}"

# Last chapter: from last start to end of file
file="${escbook}/$(printf "%.2d" "${track}")-${esctitle}"
ffmpeg -i "${inputaudio}" -nostdin -y -ss "${start}" -vn -c:a libopus -b:a 96k "${file}.opus"
tag.sh -a "${author}" -t "${title}" -A "${booktitle}" -n "${track}" -N "${total}" -d "${year}" "${file}.opus"
