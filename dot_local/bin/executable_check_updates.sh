#!/bin/bash

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/updates"
update_file="${cache_dir}/yay_updates_count"
cache_time=7200

mkdir -p "${cache_dir}"

check_updates() {
        if [ -f /etc/gentoo-release ]; then
                local su="sudo"
                command -v doas &> /dev/null && su="doas"

                $su emaint sync -a 2> /dev/null
                total=$(emerge -pvu @world 2> /dev/null | rg -c '^\[ebuild')
        else
                local repo_updates=0
                local aur_updates=0

                command -v checkupdates &> /dev/null && repo_updates=$(checkupdates 2> /dev/null | wc -l)
                command -v yay &> /dev/null && aur_updates=$(yay -Qua 2> /dev/null | wc -l)

                total=$((repo_updates + aur_updates))
        fi

        echo "${total}" > "${update_file}"
}

current_time=$(date +%s)
threshold_time=$((current_time - cache_time))
file_mtime=$(stat -c %Y "${update_file}" 2> /dev/null || echo "0")

if [ -f /etc/gentoo-release ]; then
        icon="  "
else
        icon=" 󰮯 "
fi

if [ ! -e "${update_file}" ] || [ "${file_mtime}" -lt "${threshold_time}" ]; then
        check_updates &
        echo "$icon"
else
        updates_count=$(cat "${update_file}" 2> /dev/null || echo "0")

        if [ -n "${updates_count}" ] && [ "${updates_count}" -gt 0 ] 2> /dev/null; then
                echo "${icon% } ${updates_count}"
        else
                echo "$icon"
        fi
fi
