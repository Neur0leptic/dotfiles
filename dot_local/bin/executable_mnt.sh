#!/bin/bash

r() {
        tmp="/tmp/rofi_mnt_$$"
        cat > "$tmp"

        local x=$(awk -F'\0' '{print length($1)}' "$tmp" | sort -rn | head -1)
        [ -z "$x" ] && x=10

        local chk=$(printf '%s' "${1}" | awk '{print length($0)}')
        [ "$x" -lt "$chk" ] && x="$chk"

        x=$((x + 15))

        [ "$x" -lt 35 ] && x=35
        [ "$x" -gt 120 ] && x=120

        cat "$tmp" | rofi -dmenu -i -show-icons -p "${1}" -theme-str "window { width: ${x}ch; }"
        rm -f "$tmp"
}

s="$(printf "mount\0icon\037drive-removable-media\numount\0icon\037media-eject\n" | r "Select Preference:")"

[[ ${s} ]] || exit "0"

m() {
        doas findmnt -lno SOURCE "${1}"
}

ns() {
        notify-send "Drive Mounter" "${@}"
}

is_mounted() {
        grep -qs "^${1} " "/proc/mounts"
}

n() {
        case "${1}" in
                "sm") ns "\"${PART}\" ${s}ed to \"${MP}\"" ;;
                "su") ns "\"${PART}\" ${s}ed from \"${MP}\"" ;;
                "fm") ns "Failed to ${s} \"${PART}\" to \"${MP}\"" ;;
                "fu") ns "Failed to ${s} \"${PART}\" from \"${MP}\"" ;;
        esac
}

ns "Searching available parts..."

P_R="$(m "/")"
P_B="$(m "/boot")"
P_H="$(m "/home")"

IFS=$'\n'
for i in $(doas lsblk -lnfo NAME,FSTYPE,SIZE); do
        [[ ! "${i%% *}" =~ [a-z]$ ]] &&
                i="/dev/${i}" &&
                [[ ! "${i%% *}" == "${P_R}" ]] &&
                [[ ! "${i%% *}" == "${P_B}" ]] &&
                [[ ! "${i%% *}" == "${P_H}" ]] &&
                [[ ! "${i%% *}" =~ ^.*n[0-9]$ ]] &&
                [[ ! "${i}" =~ ^[^\ ]+[\ ]+[^\ ]+$ ]] && {
                [[ "${s}" == "mount" ]] && ! is_mounted "${i%% *}" &&
                        parts+=("${i}")
                [[ "${s}" == "umount" ]] && is_mounted "${i%% *}" &&
                        parts+=("${i}")
        }
done

[[ ${#parts[@]} == "0" ]] && {
        ns "No partition available for ${s}ing."
        exit "1"
}

PART="$(printf "%s\n" "${parts[@]}" | r "Select partition:" "${#parts[@]}")"
[[ "${PART}" ]] || {
        ns "No partition selected."
        exit "1"
}

IFS=' ' read -r -a pt_dts <<< "${PART}"
PART="${pt_dts[0]}"
FS="${pt_dts[1]}"

[[ "${s}" == "mount" ]] && {
        for i in "/mnt/"*; do
                MPs+=("${i}")
        done

        [[ ${#MPs[@]} == "0" ]] && {
                ns "no mount points available in /mnt"
                exit "1"
        }

        MP="$(printf "%s\n" "${MPs[@]}" | r "Select mount point:" "${#MPs[@]}")"
        [[ "${MP}" ]] || {
                ns "No ${s} point selected."
                exit "1"
        }

        [[ "${FS}" == ntfs ]] && FS="ntfs3"
        [[ "${FS}" =~ ^(ext4|f2fs|btrfs|xfs)$ ]] && {
                doas "${s}" -s -t "${FS}" "${PART}" "${MP}" -o "defaults,noatime" && n "sm" || n "fm"
                doas chown -R "${USER}:${USER}" "${MP}"
        } || {
                doas "${s}" -s -t "${FS}" -o "defaults,uid=${USER},gid=${USER},noatime" "${PART}" "${MP}" && n "sm" || n "fm"
        }
} || {
        MP="$(findmnt -lno TARGET "${PART}")"
        doas "${s}" "${PART}" && n "su" || n "fu"
}
