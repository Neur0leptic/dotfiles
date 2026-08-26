#!/bin/sh

IPFS_MODE="false"
[ "${1}" = "-i" ] && {
	IPFS_MODE="true"
	shift
}

PURPLE="$(printf '\033[1;95m')" CYAN="$(printf '\033[1;96m')" WHITE="$(printf '\033[1;97m')"
GREEN="$(printf '\033[1;92m')" YELLOW="$(printf '\033[1;93m')" NC="$(printf '\033[0m')"
RED="$(printf '\033[1;91m')" BLUE="$(printf '\033[1;94m')"

ANNA_DOMAIN="annas-archive.gl"
MAX_RETRIES="15"
RETRY_DELAY="6"
IPFS_GATEWAYS="cloudflare-ipfs.com gateway.ipfs.io gateway.pinata.cloud"

get_useragent() {
	CACHE_FILE="/tmp/ff_ua"
	CACHE_MAX_AGE="86400"
	if [ -f "$CACHE_FILE" ] && [ "$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))" -lt "$CACHE_MAX_AGE" ]; then
		cat "$CACHE_FILE"
		return
	fi
	VER="$(curl -s --connect-timeout 5 'https://product-details.mozilla.org/1.0/firefox_versions.json' | grep -oP '"LATEST_FIREFOX_VERSION"[^,]*' | grep -oP '\d+\.\d+(\.\d+)?' 2>/dev/null)"
	[ -z "$VER" ] && VER="125.0"
	UA="Mozilla/5.0 (Windows NT 10.0; rv:${VER%.*}.0) Gecko/20100101 Firefox/${VER}"
	printf '%s' "$UA" > "$CACHE_FILE"
	printf '%s' "$UA"
}

USERAGENT="$(get_useragent)"

FQUERY=""
for arg; do
	FQUERY="${FQUERY}${arg}+"
done
QUERY="${FQUERY%+}"

QUERY="$(printf '%s' "$QUERY" | sed 's/ /+/g')"

FILENAME="$(printf '%s' "$QUERY" | tr '+' '_')_$(date +%s)"
FILENAME="${FILENAME}.pdf"

SEARCH_URL="https://${ANNA_DOMAIN}/search?index=&q=${QUERY}&content=book_nonfiction&content=book_fiction&content=book_unknown&ext=pdf&acc=external_download&src=lgli&src=lgrs&sort=&lang=en&lang=_empty"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

RESULTS_FILE="${TMPDIR}/results.html"
TITLES_FILE="${TMPDIR}/titles"
AUTHORS_FILE="${TMPDIR}/authors"
PUBLISHERS_FILE="${TMPDIR}/publishers"
SIZES_FILE="${TMPDIR}/sizes"
URLS_FILE="${TMPDIR}/urls"

printf '%s\n' "Searching..." >&2

curl -fSLk -s -A "$USERAGENT" "$SEARCH_URL" -o "$RESULTS_FILE" || {
	printf '%s\n' "${RED}Failed to fetch search results.${NC}"
	exit 1
}

sed '/partial matches/,$d' "$RESULTS_FILE" | grep -oP '<a href="/md5/[a-f0-9]+"[^>]*class="[^"]*line-clamp-\[3\][^>]*>' | grep -oP '/md5/[a-f0-9]+' | head -n 25 > "$URLS_FILE"
sed '/partial matches/,$d' "$RESULTS_FILE" | grep -oP 'class="[^"]*line-clamp-\[3\][^"]*"[^>]*>\K[^<]+(?=</a>)' | head -n 25 > "$TITLES_FILE"
sed '/partial matches/,$d' "$RESULTS_FILE" | grep -oP 'mdi--user-edit[^>]*></span>\s*\K[^<]+' | head -n 25 > "$AUTHORS_FILE"
sed '/partial matches/,$d' "$RESULTS_FILE" | grep -oP 'mdi--company[^>]*></span>\s*\K[^<]+' | head -n 25 > "$PUBLISHERS_FILE"
sed '/partial matches/,$d' "$RESULTS_FILE" | grep -oP '(?<=· )[\d.]+(?:MB|GB)' | head -n 25 > "$SIZES_FILE"

TOTAL="$(wc -l < "$URLS_FILE")"
[ "$TOTAL" -eq 0 ] && {
	printf '%s\n' "${RED}No results found.${NC}"
	exit 1
}

i=1
while [ "$i" -le "$TOTAL" ]; do
	TITLE="$(sed -n "${i}p" "$TITLES_FILE" | sed "s/&#39;/\'/g; s/&amp;/\&/g")"
	AUTHOR="$(sed -n "${i}p" "$AUTHORS_FILE" | sed "s/&#39;/\'/g; s/&amp;/\&/g")"
	PUBLISHER="$(sed -n "${i}p" "$PUBLISHERS_FILE" | sed "s/&#39;/\'/g; s/&amp;/\&/g")"
	SIZE="$(sed -n "${i}p" "$SIZES_FILE")"

	printf "${PURPLE}%d) ${WHITE}Title: ${CYAN}%s${NC}\n" "$i" "$TITLE"
	printf "${WHITE}Author: ${YELLOW}%s${NC}\n" "$AUTHOR"
	[ -n "$PUBLISHER" ] && printf "${WHITE}Publisher: ${GREEN}%s${NC}\n" "$PUBLISHER"
	[ -n "$SIZE" ] && printf "${WHITE}Size: ${RED}%s${NC}\n\n" "$SIZE" || printf '\n'
	i=$((i + 1))
done

printf "Enter your selection: "
read -r SELECTED_BOOK

CHOSEN_URL="$(sed -n "${SELECTED_BOOK}p" "$URLS_FILE")"
[ -z "$CHOSEN_URL" ] && {
	printf '%s\n' "${RED}Invalid selection.${NC}"
	exit 1
}

FULL_URL="https://${ANNA_DOMAIN}${CHOSEN_URL}"

printf '\n%s\n\n' "${GREEN}Fetching book page...${NC}"

BOOK_PAGE="$(curl -fk -sSL -A "$USERAGENT" "$FULL_URL")" || {
	printf '%s\n' "${RED}Failed to fetch book page.${NC}"
	exit 1
}

LIBGEN_LI_LINK="$(printf '%s' "$BOOK_PAGE" | grep -oP 'https://libgen\.li/file\.php\?id=[0-9]+' | head -1)"
LIBGEN_PW_LINK="$(printf '%s' "$BOOK_PAGE" | grep -oP 'https://libgen\.pw/book/[a-f0-9]+' | head -1)"
LIBGEN_IS_LINK="$(printf '%s' "$BOOK_PAGE" | grep -oP 'https://libgen\.is/book/index\.php\?md5=[A-F0-9]+' | head -1)"
AA_IPFS_LINK="$(printf '%s' "$BOOK_PAGE" | grep -oP '/ipfs_downloads/md5:[a-f0-9]+' | head -1)"

if [ "$IPFS_MODE" = "true" ]; then
	DOWNLOAD_LINKS=""
	if [ -n "$LIBGEN_LI_LINK" ]; then
		LIBGENLI_PAGE="$(curl -fk -sSL -A "$USERAGENT" "$LIBGEN_LI_LINK")"
		DOWNLOAD_LINKS="$(printf '%s' "$LIBGENLI_PAGE" | grep -oP 'href="\Khttps://[^"]*(?:cloudflare-ipfs|gateway\.ipfs|gateway\.pinata)[^"]*' | sort -u)"
	fi
	if [ -z "$DOWNLOAD_LINKS" ] && [ -n "$AA_IPFS_LINK" ]; then
		AA_IPFS_URL="https://${ANNA_DOMAIN}${AA_IPFS_LINK}"
		AA_IPFS_PAGE="$(curl -fk -sSL -A "$USERAGENT" "$AA_IPFS_URL")"
		DOWNLOAD_LINKS="$(printf '%s' "$AA_IPFS_PAGE" | grep -oP 'href="\Khttps://[^"]*(?:cloudflare-ipfs|gateway\.ipfs|gateway\.pinata)[^"]*' | sort -u)"
	fi

	if [ -z "$DOWNLOAD_LINKS" ]; then
		printf '%s\n' "No IPFS links found for this selection."
		exit 0
	fi

	for gw in $DOWNLOAD_LINKS; do
		printf '%s\n' "${GREEN}Trying: ${BLUE}${gw}${NC}"
		if curl -fSLk -A "$USERAGENT" -o "$FILENAME" "$gw" && pdfinfo "$FILENAME" >/dev/null 2>&1; then
			printf '\n%s\n' "${GREEN}Download successful.${NC}"
			printf '%s %s\n' "${WHITE}File:${NC}" "${RED}$(find . -maxdepth 1 -name "${FILENAME}" -type f)${NC}"
			exit 0
		fi
	done

	printf '\n%s\n' "All IPFS gateways failed. Try opening the links manually in a browser."
	printf '%s\n' "$DOWNLOAD_LINKS"
	exit 0
fi

DOWNLOAD_LINKS=""

# Try libgen.li → IPFS gateways
[ -n "$LIBGEN_LI_LINK" ] && {
	LIBGENLI_PAGE="$(curl -fk -sSL -A "$USERAGENT" "$LIBGEN_LI_LINK")"
	DOWNLOAD_LINKS="$(printf '%s' "$LIBGENLI_PAGE" | grep -oP 'href="\Khttps://[^"]*(?:cloudflare-ipfs|gateway\.ipfs|gateway\.pinata)[^"]*' | sort -u)"
}

printf '\n%s\n' "${GREEN}Downloading...${NC}"

downloaded="false"
attempt=1

while [ "$attempt" -le "$MAX_RETRIES" ]; do
	printf "${GREEN}Attempt ${RED}%d ${GREEN}of ${RED}%d${NC}\n" "$attempt" "$MAX_RETRIES"

	for link in $DOWNLOAD_LINKS; do
		if curl -fSLk -A "$USERAGENT" -o "$FILENAME" "$link" 2>/dev/null && pdfinfo "$FILENAME" >/dev/null 2>&1; then
			downloaded="true"
			break
		fi
		rm -f "$FILENAME"
	done

	[ "$downloaded" = "true" ] && break

	# Fallback: try libgen.pw
	if [ "$attempt" -eq 3 ] && [ -n "$LIBGEN_PW_LINK" ]; then
		LIBGENPW_PAGE="$(curl -fk -sSL --connect-timeout 10 -A "$USERAGENT" "$LIBGEN_PW_LINK" 2>/dev/null)"
		PW_LINKS="$(printf '%s' "$LIBGENPW_PAGE" | grep -oP 'href="\Khttps://[^"]*\.(?:pdf|epub)[^"]*' 2>/dev/null)"
		for plink in $PW_LINKS; do
			if curl -fSLk -A "$USERAGENT" -o "$FILENAME" "$plink" 2>/dev/null && pdfinfo "$FILENAME" >/dev/null 2>&1; then
				downloaded="true"
				break
			fi
			rm -f "$FILENAME"
		done
		[ "$downloaded" = "true" ] && break
	fi

	# Fallback: try libgen.is
	if [ "$attempt" -eq 6 ] && [ -n "$LIBGEN_IS_LINK" ]; then
		LIBGENIS_PAGE="$(curl -fk -sSL --connect-timeout 10 -A "$USERAGENT" "$LIBGEN_IS_LINK" 2>/dev/null)"
		IS_LINKS="$(printf '%s' "$LIBGENIS_PAGE" | grep -oP 'href="\Khttps://[^"]*\.(?:pdf|epub)[^"]*' 2>/dev/null)"
		for ilink in $IS_LINKS; do
			if curl -fSLk -A "$USERAGENT" -o "$FILENAME" "$ilink" 2>/dev/null && pdfinfo "$FILENAME" >/dev/null 2>&1; then
				downloaded="true"
				break
			fi
			rm -f "$FILENAME"
		done
		[ "$downloaded" = "true" ] && break
	fi

	printf "${RED}Download failed, retrying in ${BLUE}%d seconds...${NC}\n" "$RETRY_DELAY"
	sleep "$RETRY_DELAY"
	attempt=$((attempt + 1))
done

if [ "$downloaded" != "true" ]; then
	printf '%s\n' "${RED}Download failed after ${MAX_RETRIES} attempts.${NC}"
	if [ -n "$DOWNLOAD_LINKS" ]; then
		printf '\n%s\n' "${YELLOW}Try opening these links in a browser:${NC}"
		printf '%s\n' "$DOWNLOAD_LINKS"
	fi
	exit 1
fi

printf '\n%s\n' "${GREEN}Download successful.${NC}"
printf '%s %s\n' "${WHITE}File:${NC}" "${RED}$(find . -maxdepth 1 -name "${FILENAME}" -type f)${NC}"
