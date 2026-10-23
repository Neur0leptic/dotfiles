#!/bin/sh

# Ask for a title, author, year and language, search LibGen for PDFs and save
# the chosen book in ~/Books. A question left empty is not used as a filter.
# Words given as arguments skip the questions: get_books.sh pride prejudice

LIBGEN_DOMAIN="libgen.li"
BOOKS_DIR="${HOME}/Books"
TRIES="3"
RETRY_DELAY="5"

# Colors follow the rofi theme: prompts yellow, details blue, saved green, errors red.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	YELLOW="$(printf '\033[33m')" BLUE="$(printf '\033[34m')" GREEN="$(printf '\033[32m')"
	RED="$(printf '\033[31m')" BOLD="$(printf '\033[1m')" NC="$(printf '\033[0m')"
else
	YELLOW="" BLUE="" GREEN="" RED="" BOLD="" NC=""
fi

SEP="$(printf '\037')"

# Prints the number of matching files ("?" when the page has none), then one
# line per book: title, authors, publisher, year, language, size and md5,
# separated by \037.
PARSE='
function clean(s) {
	gsub(/<[^>]*>/, " ", s)
	gsub(/&nbsp;/, " ", s); gsub(/&quot;/, "\"", s); gsub(/&#0*39;/, "\047", s)
	gsub(/&lt;/, "<", s); gsub(/&gt;/, ">", s); gsub(/&amp;/, "\\&", s)
	gsub(/[[:space:]]+/, " ", s); gsub(/^ | $/, "", s)
	return s
}
{ page = page $0 " " }
END {
	total = "?"
	if (match(page, /curtab=f">Files <span class="badge badge-primary">[0-9]+/)) {
		total = substr(page, RSTART, RLENGTH)
		sub(/.*>/, "", total)
	}
	print total
	start = index(page, "id=\"tablelibgen\"")
	if (!start) exit
	page = substr(page, start)
	stop = index(page, "</table>")
	if (stop) page = substr(page, 1, stop - 1)
	rows = split(page, row, /<\/tr>/)
	for (r = 1; r <= rows; r++) {
		if (split(row[r], cell, /<td[^>]*>/) < 10 || !match(row[r], /md5=[0-9a-fA-F]+/)) continue
		md5 = tolower(substr(row[r], RSTART + 4, RLENGTH - 4))
		title = ""
		if (match(cell[2], /href="edition\.php\?id=[0-9]+"[^>]*>/)) {
			title = substr(cell[2], RSTART + RLENGTH)
			sub(/<\/a>.*/, "", title)
		}
		print clean(title) "\037" clean(cell[3]) "\037" clean(cell[4]) "\037" clean(cell[5]) \
			"\037" clean(cell[6]) "\037" clean(cell[8]) "\037" md5
	}
}'

# Two lines per book: number and title, then authors, publisher, year, language and size.
SHOW='
function names(s, sep,    part, n, i, out, seen) {
	n = split(s, part, /[[:space:]]*;[[:space:]]*/)
	for (i = 1; i <= n; i++) {
		sub(/[[:space:],]+$/, "", part[i])
		if (part[i] == "" || (part[i] in seen)) continue
		seen[part[i]] = 1
		out = out (out == "" ? "" : sep) part[i]
	}
	return out
}
function add(s) {
	if (s != "") details = details (details == "" ? "" : " · ") s
}
BEGIN { FS = "\037" }
{
	author = (split($2, part, /[[:space:]]*;[[:space:]]*/) > 2) ? names(part[1], "") " et al." : names($2, "; ")
	details = ""
	add(author); add($3); add($4); add(names($5, ", ")); add($6)
	printf "%s%2d%s  %s%s%s\n", cy, NR, cn, cw, $1, cn
	if (details != "") printf "    %s%s%s\n", cb, details, cn
}'

info() {
	printf '%s%s%s\n' "$BLUE" "$1" "$NC"
}

error() {
	printf '%s%s%s\n' "$RED" "$1" "$NC" >&2
}

get_useragent() {
	CACHE_FILE="${TMPDIR:-/tmp}/ff_ua"
	CACHE_MAX_AGE="86400"
	if [ -f "$CACHE_FILE" ] && [ "$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))" -lt "$CACHE_MAX_AGE" ]; then
		cat "$CACHE_FILE"
		return
	fi
	VER="$(curl -s --connect-timeout 5 --max-time 10 'https://product-details.mozilla.org/1.0/firefox_versions.json' |
		sed -n 's/.*"LATEST_FIREFOX_VERSION": *"\([0-9]*\)\..*/\1/p' | head -n 1)"
	[ -z "$VER" ] && VER="144"
	UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:${VER}.0) Gecko/20100101 Firefox/${VER}.0"
	printf '%s' "$UA" > "$CACHE_FILE"
	printf '%s' "$UA"
}

# LibGen language codes; most of its files use these three-letter forms.
lang_code() {
	CODE="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
	case "$CODE" in
	'') ;;
	en | english) printf 'eng' ;;
	tr | turkish) printf 'tur' ;;
	de | deu | german) printf 'ger' ;;
	fr | fra | french) printf 'fre' ;;
	es | spanish) printf 'spa' ;;
	it | italian) printf 'ita' ;;
	pt | portuguese) printf 'por' ;;
	ru | russian) printf 'rus' ;;
	nl | nld | dutch) printf 'dut' ;;
	ar | arabic) printf 'ara' ;;
	fa | per | persian) printf 'fas' ;;
	el | ell | greek) printf 'gre' ;;
	la | latin) printf 'lat' ;;
	zh | zho | chinese) printf 'chi' ;;
	ja | japanese) printf 'jpn' ;;
	pl | polish) printf 'pol' ;;
	[a-z][a-z][a-z]) printf '%s' "$CODE" ;;
	*) return 1 ;;
	esac
}

ask() {
	printf '%s%s%s ' "$YELLOW" "$1" "$NC"
	read -r ANSWER || {
		printf '\n'
		exit 0
	}
}

ask_questions() {
	printf '%sBook search. Press Enter to skip a question.%s\n\n' "$BLUE" "$NC"
	while :; do
		ask "Title:"
		TITLE="$ANSWER"
		ask "Author:"
		AUTHOR="$ANSWER"
		[ -n "${TITLE}${AUTHOR}" ] && break
		error "Type a title or an author."
	done
	while :; do
		ask "Year:"
		YEAR="$ANSWER"
		case "$YEAR" in
		'' | [0-9][0-9][0-9][0-9]) break ;;
		esac
		error "Type a year such as 1999, or press Enter to skip."
	done
	while :; do
		ask "Language (e.g. English or en):"
		BOOK_LANG="$(lang_code "$ANSWER")" && break
		error "Unknown language. Type a name such as English or a code such as en."
	done
}

# $1: words to search, $2: LibGen columns to search them in
# Returns 1 when LibGen cannot be reached and 2 when its page cannot be read.
search() {
	REQ="$(printf '%s' "$1" | sed 's/["*:+~<>()@-]/ /g') ext:pdf"
	[ -n "$YEAR" ] && REQ="${REQ} year:${YEAR}"
	[ -n "$BOOK_LANG" ] && REQ="${REQ} lang:${BOOK_LANG}"
	curl -fsS --connect-timeout 20 --max-time 60 -A "$USERAGENT" -o "${WORK}/page.html" \
		-G "https://${LIBGEN_DOMAIN}/index.php" --data-urlencode "req=${REQ}" \
		--data "${2}&objects%5B%5D=f&topics%5B%5D=l&topics%5B%5D=f&res=25&filesuns=all&gmode=on" || return 1
	awk "$PARSE" "${WORK}/page.html" > "${WORK}/parsed"
	TOTAL="$(sed -n 1p "${WORK}/parsed")"
	sed 1d "${WORK}/parsed" > "${WORK}/books"
	COUNT="$(wc -l < "${WORK}/books")"
	# Every LibGen result page shows its file count, even when nothing matches.
	[ "$TOTAL" = "?" ] && return 2
	[ "$TOTAL" -gt 0 ] && [ "$COUNT" -eq 0 ] && return 2
	return 0
}

show_results() {
	printf '\n'
	awk -v cy="$YELLOW" -v cb="$BLUE" -v cw="$BOLD" -v cn="$NC" "$SHOW" "${WORK}/books"
	[ "$TOTAL" -gt "$COUNT" ] 2>/dev/null &&
		printf '%sShowing %d of %d. Add more details to narrow the list.%s\n' "$BLUE" "$COUNT" "$TOTAL" "$NC"
}

# "Author - Title" without characters that cannot be in a file name, cut to
# 180 bytes so the year and ".pdf" still fit
book_name() {
	printf '%s\n%s\n' "$1" "$2" | awk '
		NR == 1 { author = $0; sub(/[[:space:]]*;.*/, "", author); sub(/[[:space:],]+$/, "", author) }
		NR == 2 { title = $0 }
		END {
			if (title == "") exit
			name = (author != "" ? author " - " : "") title
			gsub(/\//, "-", name)
			gsub(/[[:cntrl:]]/, "", name)
			gsub(/[[:space:]]+/, " ", name)
			sub(/^[ .-]+/, "", name)
			print name
		}' | cut -b 1-180 | iconv -c -f UTF-8 -t UTF-8 2>/dev/null | sed 's/[ .]*$//'
}

get_book() {
	ROW="$(sed -n "${1}p" "${WORK}/books")"
	OLD_IFS="$IFS"
	IFS="$SEP"
	set -f
	set -- $ROW
	set +f
	IFS="$OLD_IFS"
	B_TITLE="$1" B_AUTHOR="$2" B_YEAR="$4" B_MD5="$7"

	mkdir -p "$BOOKS_DIR" || {
		error "Could not create ${BOOKS_DIR}."
		return 1
	}

	printf '\n%sDownloading:%s %s\n' "$BLUE" "$NC" "$B_TITLE"
	try=1
	while :; do
		# The download link carries a key, so it is fetched again for every try.
		LINK="$(curl -fsS --connect-timeout 20 --max-time 60 -A "$USERAGENT" "https://${LIBGEN_DOMAIN}/ads.php?md5=${B_MD5}" |
			sed -n 's/.*href="\(get\.php?md5=[^"]*\)".*/\1/p' | head -n 1 | sed 's/&amp;/\&/g')"
		[ -n "$LINK" ] &&
			curl -fL $PROGRESS --connect-timeout 20 --speed-limit 1024 --speed-time 60 -A "$USERAGENT" \
				-o "${WORK}/book.pdf" "https://${LIBGEN_DOMAIN}/${LINK}" &&
			pdfinfo "${WORK}/book.pdf" >/dev/null 2>&1 && break
		rm -f "${WORK}/book.pdf"
		[ "$try" -ge "$TRIES" ] && {
			error "Download did not work. Try another number."
			return 1
		}
		try=$((try + 1))
		error "Download failed. Trying again in ${RETRY_DELAY} seconds (${try} of ${TRIES})..."
		sleep "$RETRY_DELAY"
	done

	NAME="$(book_name "$B_AUTHOR" "$B_TITLE")"
	[ -n "$NAME" ] || NAME="$B_MD5"
	case "$B_YEAR" in
	[0-9][0-9][0-9][0-9]) NAME="${NAME} (${B_YEAR})" ;;
	esac
	DEST="${BOOKS_DIR}/${NAME}.pdf"
	i=2
	while [ -e "$DEST" ]; do
		DEST="${BOOKS_DIR}/${NAME} (${i}).pdf"
		i=$((i + 1))
	done
	mv "${WORK}/book.pdf" "$DEST" || {
		error "Could not save the book in ${BOOKS_DIR}."
		return 1
	}
	printf '%sSaved:%s %s\n' "$GREEN" "$NC" "$DEST"
}

# Returns when a new search is wanted; quits after q or a saved book.
choose_book() {
	while :; do
		printf '\n%sNumber to download, Enter for a new search, q to quit:%s ' "$YELLOW" "$NC"
		read -r CHOICE || {
			printf '\n'
			exit 0
		}
		case "$CHOICE" in
		'')
			printf '\n'
			return
			;;
		q | Q) exit 0 ;;
		*[!0-9]*) ;;
		*)
			if [ "$CHOICE" -ge 1 ] 2>/dev/null && [ "$CHOICE" -le "$COUNT" ]; then
				get_book "$CHOICE" && exit 0
				continue
			fi
			;;
		esac
		if [ "$COUNT" -eq 1 ]; then
			error "Type 1 to download this book."
		else
			error "Type a number from 1 to ${COUNT}."
		fi
	done
}

case "${1:-}" in
-*)
	printf '%s\n' "Usage: get_books.sh [words from the title or author]" >&2
	exit 1
	;;
esac

command -v curl >/dev/null 2>&1 || {
	error "curl is missing. Install curl first."
	exit 1
}
command -v pdfinfo >/dev/null 2>&1 || {
	error "pdfinfo is missing. Install poppler first."
	exit 1
}

USERAGENT="$(get_useragent)"

WORK="$(mktemp -d)" || exit 1
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

if [ -t 2 ]; then
	PROGRESS="--progress-bar"
else
	PROGRESS="--silent --show-error"
fi

WORDS="$*"
while :; do
	if [ -n "$WORDS" ]; then
		TITLE="" AUTHOR="" YEAR="" BOOK_LANG=""
		QUERY="$WORDS"
		FIELDS="columns%5B%5D=t&columns%5B%5D=a"
		WORDS=""
	else
		ask_questions
		QUERY="${TITLE} ${AUTHOR}"
		FIELDS=""
		[ -n "$TITLE" ] && FIELDS="columns%5B%5D=t"
		[ -n "$AUTHOR" ] && FIELDS="${FIELDS:+${FIELDS}&}columns%5B%5D=a"
	fi

	printf '\n'
	info "Searching LibGen..."
	search "$QUERY" "$FIELDS"
	case "$?" in
	1)
		error "Could not reach LibGen. Check your connection and try again."
		exit 1
		;;
	2)
		error "LibGen sent a page this script cannot read. The site may be down or may have changed."
		exit 1
		;;
	esac
	[ "$COUNT" -gt 0 ] || {
		error "No PDF found. Try fewer words, or leave the year and language empty."
		printf '\n'
		continue
	}
	show_results
	choose_book
done
