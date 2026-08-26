#!/bin/dash

is_descendant() {
    child=$1; parent=$2; p=$child
    while [ "$p" != "1" ] && [ -n "$p" ]; do
        [ "$p" = "$parent" ] && return 0
        p=$(ps -o ppid= -p "$p" 2>/dev/null | awk '{print $1}')
    done
    return 1
}

extract_name() {
    class=$1; title=$2
    case "$class" in
        foot|footclient|foot-*)
            name=$(echo "$title" | awk '{print $1}' | sed 's/[^a-zA-Z0-9].*$//')
            ;;
        *)
            name=$(echo "$class" | sed 's/[-_].*$//')
            ;;
    esac
    echo "$name"
}

find_target() {
    server_pid=$1; class=$2; title=$3

    name=$(extract_name "$class" "$title")
    [ -z "$name" ] && return 1

    case "$name" in foot|footclient|sh|zsh|bash|dash|fish|"~") return 1 ;; esac

    lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')

    for match in $(pgrep -x "$name" 2>/dev/null; pgrep -x "$lower" 2>/dev/null); do
        if is_descendant "$match" "$server_pid"; then
            echo "$match"
            return 0
        fi
    done
    return 1
}

json=$(hyprctl activewindow -j 2>/dev/null)

pid=$(echo "$json" | sed -n 's/.*"pid": *\([0-9]*\).*/\1/p')
class=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('class',''))" 2>/dev/null)
title=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))" 2>/dev/null)

if [ -z "$pid" ] || [ "$pid" -le 0 ] 2>/dev/null; then
    notify-send "Panic Kill" "no focused window" 2>/dev/null
    exit 1
fi

comm=$(ps -p "$pid" -o comm= 2>/dev/null)

case "$comm" in
    foot|kitty)
        target=$(find_target "$pid" "$class" "$title")
        if [ -z "$target" ]; then
            notify-send "Panic Kill" "no process found in terminal" 2>/dev/null
            exit 1
        fi
        ;;
    *)
        target=$pid
        ;;
esac

notify-send "Panic Kill" "killing $target ($(ps -p $target -o comm= 2>/dev/null))" 2>/dev/null

kill -15 "$target" 2>/dev/null
sleep 2

if kill -0 "$target" 2>/dev/null; then
    kill -9 "$target" 2>/dev/null
    notify-send "Panic Kill" "force killed PID $target" 2>/dev/null
else
    notify-send "Panic Kill" "terminated PID $target" 2>/dev/null
fi
