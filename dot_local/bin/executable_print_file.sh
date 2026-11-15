#!/bin/sh
# Print files on the home printer over IPP, without CUPS.
# The printer (Lexmark CS310dn) renders PDF, PostScript and JPEG itself;
# this script asks for its highest resolution, 1200 dpi.
#
# Usage: print_file.sh [-d] [-n copies] [-p pages] file...
#   -d          print on both sides (flip on the long edge)
#   -n copies   number of copies (default 1)
#   -p pages    pages to print, for example 1-3,7 or 5- (default all)
#
# Set PRINTER_URI to use another printer address.

printer=${PRINTER_URI:-ipp://192.168.0.122/ipp/print}

usage() {
	printf '%s\n' 'Usage: print_file.sh [-d] [-n copies] [-p pages] file...' \
		'  -d          print on both sides' \
		'  -n copies   number of copies (default 1)' \
		'  -p pages    pages to print, for example 1-3,7 or 5- (default all)' >&2
	exit 2
}

# Messages go to the terminal, or to a notification when there is no
# terminal (for example when yazi runs the script).
report() {
	if [ -t 2 ] || ! notify-send -a print_file.sh -- "$1" "$2" 2>/dev/null; then
		printf '%s: %s\n' "$1" "$2" >&2
	fi
}

sides=one-sided
copies=1
pages=
while getopts dn:p: opt; do
	case $opt in
	d) sides=two-sided-long-edge ;;
	n) copies=$OPTARG ;;
	p) pages=$OPTARG ;;
	*) usage ;;
	esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] || usage

case $copies in
[1-9] | [1-9][0-9] | [1-9][0-9][0-9]) ;;
*)
	report 'Not printed' "copies must be a number from 1 to 999, not '$copies'"
	exit 2
	;;
esac

# IPP wants every range as first-last: 7 becomes 7-7, 5- runs to the end.
bad_pages() {
	report 'Not printed' "pages must look like 1-3,7 or 5-, not '$pages'"
	exit 2
}
ranges=
case $pages in
*[!0-9,-]*) bad_pages ;;
esac
old_ifs=$IFS
IFS=,
for range in $pages; do
	case $range in
	'' | - | *-*-*) bad_pages ;;
	-*) range=1$range ;;
	*-) range=${range}2147483647 ;;
	*-*) ;;
	*) range=$range-$range ;;
	esac
	case $range in
	0* | *-0*) bad_pages ;;
	esac
	ranges=${ranges:+$ranges,}$range
done
IFS=$old_ifs

page_attr=
[ -z "$ranges" ] || page_attr="ATTR rangeOfInteger page-ranges $ranges"

# send FILE FORMAT JOB-NAME: one Print-Job request. File names and other
# free text reach ipptool only through -d and -f, never inside the request.
# While the printer answers "busy", ipptool sends the job again every
# 5 seconds, for up to 5 minutes.
send() {
	ipptool -T 30 -t -d format="$2" -d job_name="$3" -f "$1" "$printer" /dev/stdin <<EOF
{
	NAME "Print-Job"
	OPERATION Print-Job
	GROUP operation-attributes-tag
	ATTR charset attributes-charset utf-8
	ATTR naturalLanguage attributes-natural-language en
	ATTR uri printer-uri \$uri
	ATTR name requesting-user-name \$user
	ATTR name job-name \$job_name
	ATTR mimeMediaType document-format \$format
	GROUP job-attributes-tag
	ATTR integer copies $copies
	ATTR keyword sides $sides
	ATTR resolution printer-resolution 1200dpi
	$page_attr
	FILE \$filename
	STATUS successful-ok
	STATUS successful-ok-ignored-or-substituted-attributes
	STATUS server-error-busy REPEAT-MATCH REPEAT-LIMIT 60
	EXPECT job-id
}
EOF
}

status=0
for file; do
	case $file in
	/*) ;;
	*) file=$PWD/$file ;;
	esac
	name=${file##*/}
	if [ ! -f "$file" ] || [ ! -r "$file" ]; then
		report 'Not printed' "$name is not a readable file"
		status=1
		continue
	fi
	format=$(file -b --mime-type -- "$file")
	case $format in
	application/pdf | application/postscript | image/jpeg) ;;
	*)
		report 'Not printed' "$name is $format; the printer takes PDF, PostScript and JPEG"
		status=1
		continue
		;;
	esac
	# ipptool splits attribute values at commas, so the job name has none.
	job_name=$(printf '%s' "$name" | tr ',' ' ')
	if output=$(send "$file" "$format" "$job_name" 2>&1); then
		report 'Printing' "$name"
	else
		reason=$(printf '%s\n' "$output" | grep -m 1 -E 'status-code|Unable|EXPECTED|Bad|Missing' | sed 's/^[[:space:]]*//; s/^ipptool: //')
		report 'Not printed' "$name: ${reason:-printer did not accept the job}"
		status=1
	fi
done
exit $status
