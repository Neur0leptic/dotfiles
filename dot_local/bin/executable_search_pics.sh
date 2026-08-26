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

pic_files="$(locate -d "$LOCATE_DB" -b -r '.*\.\(jpeg\|jpg\|png\|webp\)$')"
[ -z "$pic_files" ] && {
    notify-send "No image files found."
    exit 0
}

chosen_file="$(echo "$pic_files" | sed 's|.*/||; s/\.[^.]*$//' | rofi -dmenu -p "Select Image")"
[ -z "$chosen_file" ] && exit 0

imv "$(echo "$pic_files" | grep -F "/${chosen_file}.")"
