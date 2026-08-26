#!/bin/sh

LOCATE_DB="${HOME}/.config/.mylocate.db"

priv() {
    if command -v pacman >/dev/null 2>&1; then
        sudo "$@"
    else
        doas "$@"
    fi
}

pm_install() {
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm plocate
    else
        doas emerge sys-apps/plocate
    fi
}

command -v locate >/dev/null || {
    notify-send "Locate not found. Installing..."
    pm_install
} || {
    notify-send "Failed. Run the script once on terminal."
    exit 1
}

[ -s "$LOCATE_DB" ] || {
    notify-send "You have no database. Creating it..."
    disk_path="$(echo "" | rofi -dmenu -p "Enter the disk path (e.g '/mnt/harddisk'): " -lines 0)"
    priv updatedb -o "$LOCATE_DB" -U "$disk_path" || {
        notify-send "Failed to create database."
        exit 1
    }
}

video_files="$(locate -d "$LOCATE_DB" -b -r '.*\.\(mp4\|mkv\|webm\|mov\|m4v\|wmv\|flv\|avi\|gif\)$')"
[ -z "$video_files" ] && {
    notify-send "No video files found."
    exit 0
}

chosen_file="$(echo "$video_files" | sed 's|.*/||; s/\.[^.]*$//' | shuf -n 1)"
selected_video="$(printf "%s\n" "$video_files" | grep -F "/${chosen_file}.")"

mpv "$selected_video"

CHOICE="$(printf "Yes\nNo" | rofi -dmenu -p "Delete this video?" -lines 2)"
[ "$CHOICE" = "Yes" ] && rm -f "$selected_video"
