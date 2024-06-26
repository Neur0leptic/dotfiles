#!/bin/bash

[ "${1}" == "-i" ] && {
	IPFS_MODE="true"
	shift
} || IPFS_MODE="false"

PURPLE='\e[1;95m' CYAN='\e[1;96m' WHITE='\e[1;97m'
GREEN='\e[1;92m' YELLOW='\e[1;93m' NC='\033[0m'
RED='\e[1;91m' BLUE='\e[1;94m'

USERAGENT="Mozilla/5.0 (Windows NT 10.0; rv:121.0) Gecko/20100101 Firefox/121.0"

FQUERY="$(printf "%s+" "${@}")"
QUERY="${FQUERY%+}"

FILENAME="${QUERY//+/_}"
FILENAME="${FILENAME,,}.pdf"

URL="https://annas-archive.org/search?index=&q=${QUERY}&content=book_nonfiction&content=book_fiction&content=book_unknown&ext=pdf&acc=external_download&src=lgli&src=lgrs&sort=&lang=en&lang=_empty"

RESULTS="$(curl -fSLk -A "${USERAGENT}" -s "${URL}" -X "GET" |
	sed '/partial matches/,$d')"

IFS=$'\n' read -r -d '' -a TITLES < <(printf "%s" "${RESULTS}" | grep -oP '(?<=<h3 class="max-lg:line-clamp-\[2\] lg:truncate leading-\[1.2\] lg:leading-\[1.35\] text-md lg:text-xl font-bold">)[^<]*' | head -n 25)
IFS=$'\n' read -r -d '' -a AUTHORS < <(printf "%s" "${RESULTS}" | grep -oP '(?<=<div class="max-lg:line-clamp-\[2\] lg:truncate leading-\[1.2\] lg:leading-\[1.35\] max-lg:text-sm italic">)[^<]*' | head -n 25)
IFS=$'\n' read -r -d '' -a PUBLISHERS < <(printf "%s" "${RESULTS}" | grep -oP '(?<=<div class="truncate leading-\[1.2\] lg:leading-\[1.35\] max-lg:text-xs">)[^<]*' | head -n 25)

IFS=$'\n' read -r -d '' -a URLS < <(printf "%s" "${RESULTS}" | grep -oP 'href="\K/md5/[^"]*' | head -n "25")
IFS=$'\n' read -r -d '' -a SIZES < <(printf "%s" "${RESULTS}" | grep -oP '(?<=pdf, )\d+(\.\d+)?MB' | head -n "25")

for i in "${!TITLES[@]}"; do
	TITLE="${TITLES[i]}"
	AUTHOR="${AUTHORS[i]}"
	PUBLISHER="${PUBLISHERS[i]}"
	SIZE="${SIZES[i]}"
	printf "${PURPLE}%d) ${WHITE}Title: ${CYAN}%s${NC}\n" "$((i + 1))" "${TITLE}"
	printf "${WHITE}Author: ${YELLOW}%s${NC}\n" "${AUTHOR}"
	[ -n "${PUBLISHER}" ] && printf "${WHITE}Publisher: ${GREEN}%s${NC}\n" "${PUBLISHER}"
	printf "${WHITE}Size: ${RED}%s${NC}\n\n" "${SIZE}"
done

printf "Enter your selection: "
read -r SELECTED_BOOK

CHOSEN_URL="${URLS[SELECTED_BOOK - 1]}"

FULL_URL="https://annas-archive.org${CHOSEN_URL}"

BOOK_PAGE_CONTENT="$(curl -fk -A "${USERAGENT}" -sSL "${FULL_URL}" -X "GET")"

"${IPFS_MODE}" && {
	IPFS_LINKS="$(printf "%s" "${BOOK_PAGE_CONTENT}" | grep -oP "(?<=<a href=')[^']*ipfs[^']*")"
	IPFS_DOWN="$(printf "%s" "${IPFS_LINKS}" | grep -o "ipfs.io[^']*")"

	[ -z "${IPFS_LINKS}" ] && { printf "There is no IPFS link for this selection.\n"; exit "0"; }

	curl -fSLk -X "GET" -A "${USERAGENT}" -o "${FILENAME}" "${IPFS_DOWN}" || { printf "${RED}%s${NC}\n" "${IPFS_LINKS}"

	printf "${BLUE}%s\n${NC}\n" "IPFS Links should be opened with a browser."
	printf "${BLUE}%s\n${NC}\n" "You may need to try a few times."
	exit "0"; }
}

LIBGEN_RS_LINK="$(printf "%s" "${BOOK_PAGE_CONTENT}" | grep -oP "(?<=<a href=')[^']*library\.lol[^']*")"
LIBGEN_LI_LINK="$(printf "%s" "${BOOK_PAGE_CONTENT}" | grep -oP "(?<=<a href=')[^']*libgen\.li[^']*")"

LIBGENLI_PAGE_CONTENT="$(curl -fk -A "${USERAGENT}" -sSL "${LIBGEN_LI_LINK}" -X "GET")"
LIBGENRS_PAGE_CONTENT="$(curl -fk -A "${USERAGENT}" -sSL "${LIBGEN_RS_LINK}" -X "GET")"

DOWNLOAD_LINK_LI="$(printf "%s" "${LIBGENLI_PAGE_CONTENT}" | grep -o 'https://cdn[0-9]*\.booksdl\.org[^"]*')"
DOWNLOAD_LINK_RS="$(printf "%s" "${LIBGENRS_PAGE_CONTENT}" | grep -o 'https://download.library.lol/.*.pdf')"

DOWNLOAD_LINK_LI="${DOWNLOAD_LINK_LI//\\/\/}"
DOWNLOAD_LINK_RS="${DOWNLOAD_LINK_RS//\\/\/}"

printf "\n${GREEN}%s\n${NC}" "Downloading and renaming..."

MAX_RETRIES="15"
RETRY_DELAY="6"

for ((attempt=1; attempt<=MAX_RETRIES; attempt++)); do
	[[ -n "${DOWNLOAD_LINK_RS}" && $((attempt % 2)) -ne 0 ]] && DOWNLOAD_LINK="${DOWNLOAD_LINK_RS}" || DOWNLOAD_LINK="${DOWNLOAD_LINK_LI}"

	printf "${GREEN}Attempt ${RED}%d ${GREEN}of ${RED}%d${NC}\n" "${attempt}" "${MAX_RETRIES}"

	curl -fSLk -X "GET" -A "${USERAGENT}" -o "${FILENAME}" "${DOWNLOAD_LINK}"

	pdfinfo "${FILENAME}" > "/dev/null" 2>&1 && {
		printf "${GREEN}Download successful.%s\n${NC}"
		break
	} || {
		printf "${RED}Download failed, retrying in ${BLUE}%d seconds...${NC}\n" "${RETRY_DELAY}"
		sleep "${RETRY_DELAY}"
	}
done

pdfinfo "${FILENAME}" > "/dev/null" 2>&1 || printf "Download failed after %d attempts.\n" "${MAX_RETRIES}"

printf "${WHITE}Your file is ready: ${RED}%s\n" "$(find . -type f -name "${FILENAME}")"
