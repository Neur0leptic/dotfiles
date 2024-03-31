#!/bin/dash

dmenu() {
        bemenu -l "${1}" -p "${2}"
}

notify() {
	notify-send "Calculator" "${1}"
}

mode="$(echo "What is A% of B?
A is What % of B?
What is the Percentage Increase/Decrease from A to B?
What If the Number A is Increased/Decreased by B%?" | dmenu "4" "Calculation Method:")"

calculate_and_fix() {
        bc -ql | sed 's/\.0*$//;s/\.$//'
}

case "${mode}" in
        "What is A% of B?")
                a="$(echo "" | dmenu "0" "Enter A (the percentage):")"
                b="$(echo "" | dmenu "0" "Enter B (the total):")"
                result="$(echo "(${a}/100)*${b}" | calculate_and_fix)"
                notify "${result}"
                ;;

        "A is What % of B?")
                a="$(echo "" | dmenu "0" "Enter A (the part):")"
                b="$(echo "" | dmenu "0" "Enter B (the whole):")"
                result="$(echo "(${a}/${b})*100" | calculate_and_fix)"
                notify "${result}%"
                ;;

        "What is the Percentage Increase/Decrease from A to B?")
                a="$(echo "" | dmenu "0" "Enter the initial value (A):")"
                b="$(echo ""| dmenu "0" "Enter the new value (B):")"
                result="$(echo "((${b}-${a})/${a})*100" | calculate_and_fix)"
		[ "${a}" -gt "${b}" ] && notify "\\${result}%" || notify "${result}%"
		;;

        "What If the Number A is Increased/Decreased by B%?")
                a="$(echo "" | dmenu "0" "Enter the number (A):")"
                b="$(echo "" | dmenu "0" "Enter the percentage increase/decrease (B%):")"
                result="$(echo "${a}+(${a}*${b}/100)" | calculate_and_fix)"
                notify "${result}"
                ;;

        *[0-9]*[\+\-\*/]* | *[\+\-\*/]*[0-9]*)
                foot -T "calculator" dash -c '
	colorize_output() {
		while IFS= read -r line; do
			processed_line="$(echo "${line}" | sed "s/\.0*$//;s/\.$//")"
            		echo "\033[1;35m${processed_line}\033[0m"
        	done
    }
	echo '\'"${mode}"\'' | bc -ql | colorize_output; bc -ql | colorize_output'
                ;;
esac
