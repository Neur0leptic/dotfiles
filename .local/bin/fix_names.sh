#!/bin/dash

[ -z "${1}" ] && {
    printf "%s\n" "Specify a directory path as an argument. e.g., fix_names.sh <path>" >&2
    exit "1"
}

[ "$(id -u)" = "0" ] && printf "%s\n" "This script should not be run as root" >&2 && exit "1"

find "${1}" -depth \( -path '*/.*' -o -path '*/.*/*' -o -path '.' \) -prune -o \( -type f -o -type d \) -print0 | sort -zr | xargs -0 -P "0" -I {} dash -c '

base="${1##*/}"
path="${1%/*}"

pattern="s/[^a-zA-Z0-9 ._-]//g; s/[ .-]/_/g; s/_+/_/g; s/^_+//; s/_+$//; s/[A-Z]/\L&/g"

[ -f "${1}" ] && pattern="${pattern}; s/_([^_]+)$/.\\1/"

new_name="$(printf "%s\n" "${base}" | sed -E "${pattern}")"

[ "${base}" != "${new_name}" ] && [ -e "${path}/${new_name}" ] && new_name="${$}_${new_name}"
[ "${base}" != "${new_name}" ] && mv "${1}" "${path}/${new_name}"
' _ {}
