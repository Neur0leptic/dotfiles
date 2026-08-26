#!/bin/bash
# sms - System, Maintain, Shutdown (Arch Linux version)

[ "$(id -u)" -eq "0" ] && {
        echo -e "\e[1;91mThis script must NOT be run as root on Arch Linux.\e[0m" >&2
        echo "yay will ask for your password automatically when needed." >&2
        exit 1
}

set -Eeo pipefail

GREEN='\e[1;92m' RED='\e[1;91m' BLUE='\e[1;94m'
PURPLE='\e[1;95m' YELLOW='\e[1;93m' NC='\033[0m'
CYAN='\e[1;96m' WHITE='\e[1;97m'

handle_error() {
        error_status="${?}"
        command_line="${BASH_COMMAND}"
        error_line="${BASH_LINENO[0]}"
        log_info r "Error on line ${BLUE}${error_line}${RED}: command ${BLUE}'${command_line}'${RED} exited with status: ${BLUE}${error_status}"
}

trap 'handle_error' ERR
trap 'handle_error' RETURN

log_info() {
        sleep "0.3"

        case "${1}" in
                g) COLOR="${GREEN}" MESSAGE="DONE!" ;;
                r) COLOR="${RED}" MESSAGE="WARNING!" ;;
                b) COLOR="${BLUE}" MESSAGE="STARTING." ;;
                c) COLOR="${BLUE}" MESSAGE="RUNNING." ;;
        esac

        COLORED_TASK_INFO="${WHITE}(${CYAN}${TASK_NUMBER}${PURPLE}/${CYAN}${TOTAL_TASKS}${WHITE})"
        MESSAGE_WITHOUT_TASK_NUMBER="${2}"

        DATE="$(date "+%Y-%m-%d ${CYAN}/${PURPLE} %H:%M:%S")"

        FULL_LOG="${CYAN}[${PURPLE}${DATE}${CYAN}] ${YELLOW}>>>${COLOR}${MESSAGE}${YELLOW}<<< ${COLORED_TASK_INFO} - ${COLOR}${MESSAGE_WITHOUT_TASK_NUMBER}${NC}"

        { [[ ${1} == "c" ]] && echo -e "\n\n${FULL_LOG}"; } || echo -e "${FULL_LOG}"
}

USER="$USER"
USER_CACHE_DIR="/home/${USER}/.cache"
VAR_TMP_DIR="/var/tmp"

update_mirrors() {
        sudo reflector --country Germany,France,Netherlands,Sweden --protocol https --latest 20 --sort rate --save /etc/pacman.d/mirrorlist 2>&1 || true
}

update_system() {
        yay -Syu --devel --noconfirm 2>&1 || true
}

validate_chezmoi_source() {
        local label="${1}"
        local source_dir="${2}"
        local private_allowlist="${3:-}"
        local inventory_file rel secret_dir secret_name plaintext_source
        local -A allowed=(
                [".chezmoiignore"]=1
                [".chezmoiversion"]=1
                [".gitignore"]=1
                ["README.md"]=1
                ["private-source-allowlist.txt"]=1
        )
        local -A forbidden=()

        if [ ! -r "$private_allowlist" ]; then
                echo -e "${YELLOW}${label} chezmoi private-source allowlist is unavailable.${NC}" >&2
                return 1
        fi

        if ! inventory_file="$(mktemp "${TMPDIR:-/tmp}/chezmoi-source-files.XXXXXX")"; then
                echo -e "${YELLOW}Could not create a temporary ${label} chezmoi inventory.${NC}" >&2
                return 1
        fi

        if ! git -C "$source_dir" ls-files --cached --others -z > "$inventory_file"; then
                rm -f "$inventory_file"
                echo -e "${YELLOW}Could not enumerate the ${label} chezmoi source.${NC}" >&2
                return 1
        fi

        if [ "$label" = "Private" ]; then
                while IFS= read -r rel || [ -n "$rel" ]; do
                        [ -n "$rel" ] || continue
                        case "$rel" in
                                */encrypted_*.asc)
                                        if [ ! -f "$source_dir/$rel" ] || [ -L "$source_dir/$rel" ]; then
                                                rm -f "$inventory_file"
                                                echo -e "${YELLOW}Required private chezmoi source is missing or not a regular file: ${rel}${NC}" >&2
                                                return 1
                                        fi
                                        allowed["$rel"]=1
                                        ;;
                                *)
                                        rm -f "$inventory_file"
                                        echo -e "${YELLOW}Invalid private chezmoi allowlist entry: ${rel}${NC}" >&2
                                        return 1
                                        ;;
                        esac
                done < "$private_allowlist"

                while IFS= read -r -d '' rel; do
                        if [ -z "${allowed[$rel]+x}" ]; then
                                rm -f "$inventory_file"
                                echo -e "${YELLOW}Unexpected file in private chezmoi source: ${rel}. Refusing automatic staging.${NC}" >&2
                                return 1
                        fi
                done < "$inventory_file"

                rm -f "$inventory_file"
                return 0
        fi

        while IFS= read -r rel || [ -n "$rel" ]; do
                [ -n "$rel" ] || continue
                case "$rel" in
                        */encrypted_*.asc) ;;
                        *)
                                rm -f "$inventory_file"
                                echo -e "${YELLOW}Invalid public private-source allowlist entry: ${rel}${NC}" >&2
                                return 1
                                ;;
                esac
                forbidden["$rel"]=1
                secret_dir="${rel%/*}"
                secret_name="${rel##*/}"
                secret_name="${secret_name#encrypted_}"
                plaintext_source="${secret_dir}/${secret_name%.asc}"
                forbidden["$plaintext_source"]=1
        done < "$private_allowlist"

        while IFS= read -r -d '' rel; do
                if [[ "$rel" == *.asc ]] || [ -n "${forbidden[$rel]+x}" ]; then
                        rm -f "$inventory_file"
                        echo -e "${YELLOW}Private payload found in public chezmoi source: ${rel}. Refusing automatic staging.${NC}" >&2
                        return 1
                fi
        done < "$inventory_file"

        rm -f "$inventory_file"
}

get_chezmoi_marker() {
        local source_dir="${1}"
        shift
        local current_head context_hash

        if ! current_head="$(git -C "$source_dir" rev-parse HEAD)"; then
                return 1
        fi

        if ! context_hash="$("$@" data | git -C "$source_dir" hash-object --stdin)"; then
                return 1
        fi

        printf '%s %s\n' "$current_head" "$context_hash"
}

record_chezmoi_marker() {
        local marker_file="${1}"
        local marker="${2}"

        if ! mkdir -p "${marker_file%/*}" || ! printf '%s\n' "$marker" > "$marker_file"; then
                return 1
        fi
}

sync_chezmoi_repo() {
        local label="${1}"
        local source_dir="${2}"
        local persistent_state="${3:-}"
        local applied_head_file="${4}"
        local private_allowlist="${5:-}"
        local source_status target_status
        local head_before_pull head_after_pull current_marker applied_marker final_marker ahead
        local source_dirty=0 target_dirty=0 apply_needed=0 changes_found=0 marker_matches=0
        local -a chezmoi_cmd=(chezmoi -S "$source_dir")

        if [ -n "$persistent_state" ]; then
                chezmoi_cmd+=(--persistent-state "$persistent_state")
        fi

        if [ ! -d "$source_dir" ]; then
                echo -e "${YELLOW}${label} chezmoi source is unavailable. Skipping it.${NC}" >&2
                return 0
        fi

        if ! git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                echo -e "${YELLOW}${label} chezmoi source is not a Git repository. Skipping it.${NC}" >&2
                return 0
        fi

        if ! validate_chezmoi_source "$label" "$source_dir" "$private_allowlist"; then
                echo -e "${YELLOW}${label} chezmoi source validation failed. Skipping it.${NC}" >&2
                return 0
        fi

        if ! git -C "$source_dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
                echo -e "${YELLOW}${label} chezmoi Git upstream is not configured. Skipping it.${NC}" >&2
                return 0
        fi

        if git -C "$source_dir" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 ||
                git -C "$source_dir" rev-parse -q --verify REBASE_HEAD >/dev/null 2>&1 ||
                git -C "$source_dir" rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null 2>&1 ||
                git -C "$source_dir" rev-parse -q --verify REVERT_HEAD >/dev/null 2>&1 ||
                [ -n "$(git -C "$source_dir" ls-files --unmerged)" ]; then
                echo -e "${YELLOW}A Git operation is in progress in the ${label} chezmoi source. Skipping it.${NC}" >&2
                return 0
        fi

        if ! current_marker="$(get_chezmoi_marker "$source_dir" "${chezmoi_cmd[@]}")"; then
                echo -e "${YELLOW}Could not calculate the ${label} chezmoi revision/profile marker. Skipping it.${NC}" >&2
                return 0
        fi

        if [ -r "$applied_head_file" ] && IFS= read -r applied_marker < "$applied_head_file" && [ "$applied_marker" = "$current_marker" ]; then
                marker_matches=1
        fi

        if ! source_status="$(git -C "$source_dir" status --porcelain)"; then
                echo -e "${YELLOW}Could not inspect the ${label} chezmoi repository. Skipping it.${NC}" >&2
                return 0
        fi

        if [ -n "$source_status" ]; then
                source_dirty=1
        fi

        if ! target_status="$("${chezmoi_cmd[@]}" --color=false status --exclude scripts --exclude externals)"; then
                echo -e "${YELLOW}Could not compare ${label} chezmoi-managed files. Skipping it.${NC}" >&2
                return 0
        fi

        if grep -q '^[ADM]' <<<"$target_status"; then
                target_dirty=1
        fi

        if grep -q '^.[ADM]' <<<"$target_status"; then
                apply_needed=1
        fi

        if [ "$source_dirty" -eq 1 ] && [ "$target_dirty" -eq 1 ]; then
                echo -e "${YELLOW}Both the ${label} chezmoi source and its managed files have local changes. Skipping it to avoid overwriting either side.${NC}" >&2
                return 0
        fi

        if [ "$target_dirty" -eq 1 ]; then
                if [ "$marker_matches" -ne 1 ]; then
                        echo -e "${YELLOW}${label} chezmoi revision or profile changed since the last successful apply. Skipping re-add to protect source changes.${NC}" >&2
                        return 0
                fi

                if ! "${chezmoi_cmd[@]}" re-add; then
                        echo -e "${YELLOW}Could not record local ${label} dotfile changes. Skipping it.${NC}" >&2
                        return 0
                fi

                if ! target_status="$("${chezmoi_cmd[@]}" --color=false status --exclude scripts --exclude externals)"; then
                        echo -e "${YELLOW}Could not verify re-added ${label} dotfiles. Skipping it.${NC}" >&2
                        return 0
                fi

                if grep -q '^.[ADM]' <<<"$target_status"; then
                        echo -e "${YELLOW}Some local ${label} changes require a manual chezmoi merge, such as templates or deletions. Skipping pull, apply and push.${NC}" >&2
                        return 0
                fi

                apply_needed=0
        elif [ "$marker_matches" -ne 1 ]; then
                apply_needed=1
        fi

        if ! validate_chezmoi_source "$label" "$source_dir" "$private_allowlist"; then
                echo -e "${YELLOW}${label} chezmoi source validation failed after re-add. Skipping commit, pull and push.${NC}" >&2
                return 0
        fi

        if ! source_status="$(git -C "$source_dir" status --porcelain)"; then
                echo -e "${YELLOW}Could not inspect re-added ${label} chezmoi changes. Skipping it.${NC}" >&2
                return 0
        fi

        if [ -n "$source_status" ]; then
                if ! git -C "$source_dir" add -A; then
                        echo -e "${YELLOW}Could not stage ${label} chezmoi changes. Skipping it.${NC}" >&2
                        return 0
                fi

                if ! git -C "$source_dir" diff --cached --quiet; then
                        if ! git -C "$source_dir" commit -m "Update dotfiles $(date '+%Y-%m-%d %H:%M:%S')"; then
                                echo -e "${YELLOW}Could not commit ${label} chezmoi changes. Skipping it.${NC}" >&2
                                return 0
                        fi
                        changes_found=1
                fi
        fi

        if ! source_status="$(git -C "$source_dir" status --porcelain)" || [ -n "$source_status" ]; then
                echo -e "${YELLOW}${label} chezmoi source is still dirty after the commit. Skipping pull, apply and push.${NC}" >&2
                return 0
        fi

        if ! head_before_pull="$(git -C "$source_dir" rev-parse HEAD)"; then
                echo -e "${YELLOW}Could not read the ${label} chezmoi Git revision. Skipping it.${NC}" >&2
                return 0
        fi

        if ! git -C "$source_dir" pull --rebase; then
                git -C "$source_dir" rebase --abort >/dev/null 2>&1 || true
                echo -e "${YELLOW}${label} chezmoi pull failed or conflicted. The rebase was aborted; skipping apply and push.${NC}" >&2
                return 0
        fi

        if ! head_after_pull="$(git -C "$source_dir" rev-parse HEAD)"; then
                echo -e "${YELLOW}Could not read the updated ${label} chezmoi Git revision. Skipping apply and push.${NC}" >&2
                return 0
        fi

        if ! validate_chezmoi_source "$label" "$source_dir" "$private_allowlist"; then
                echo -e "${YELLOW}${label} chezmoi source validation failed after pull. Skipping apply and push.${NC}" >&2
                return 0
        fi

        if [ "$head_before_pull" != "$head_after_pull" ]; then
                apply_needed=1
                changes_found=1
        fi

        if [ "$apply_needed" -eq 1 ]; then
                if ! "${chezmoi_cmd[@]}" apply; then
                        echo -e "${YELLOW}Could not apply ${label} chezmoi changes. Skipping push.${NC}" >&2
                        return 0
                fi
                changes_found=1
        fi

        if ! target_status="$("${chezmoi_cmd[@]}" --color=false status --exclude scripts --exclude externals)"; then
                echo -e "${YELLOW}Could not verify the applied ${label} chezmoi state. Skipping push.${NC}" >&2
                return 0
        fi

        if [ -n "$target_status" ]; then
                echo -e "${YELLOW}${label} chezmoi-managed files did not converge after apply. Skipping marker update and push.${NC}" >&2
                return 0
        fi

        if ! final_marker="$(get_chezmoi_marker "$source_dir" "${chezmoi_cmd[@]}")" ||
                ! record_chezmoi_marker "$applied_head_file" "$final_marker"; then
                echo -e "${YELLOW}Could not record the applied ${label} chezmoi revision/profile marker. Skipping push.${NC}" >&2
                return 0
        fi

        if ! ahead="$(git -C "$source_dir" rev-list --count '@{upstream}..HEAD')"; then
                echo -e "${YELLOW}Could not determine whether ${label} chezmoi has commits to push. Skipping push.${NC}" >&2
                return 0
        fi

        if [ "$ahead" -gt 0 ]; then
                if ! git -C "$source_dir" push; then
                        echo -e "${YELLOW}Could not push ${label} chezmoi changes. They remain committed locally.${NC}" >&2
                        return 0
                fi
                changes_found=1
        fi

        if [ "$changes_found" -eq 1 ]; then
                echo -e "${GREEN}${label} chezmoi dotfiles synchronized.${NC}"
        else
                echo -e "${BLUE}${label} chezmoi dotfiles are already synchronized.${NC}"
        fi

        return 0
}

sync_chezmoi() {
        local public_source private_source private_state public_allowlist private_allowlist
        local state_home sync_state_dir public_head private_head

        if ! command -v chezmoi >/dev/null 2>&1; then
                echo -e "${YELLOW}Chezmoi is not installed. Skipping dotfile sync.${NC}" >&2
                return 0
        fi

        if ! command -v git >/dev/null 2>&1; then
                echo -e "${YELLOW}Git is not installed. Skipping dotfile sync.${NC}" >&2
                return 0
        fi

        private_source="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi-private"
        private_state="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi-private.boltdb"
        private_allowlist="${private_source}/private-source-allowlist.txt"
        state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
        sync_state_dir="${state_home}/chezmoi-sync"
        public_head="${sync_state_dir}/public-head"
        private_head="${sync_state_dir}/private-head"

        if ! mkdir -p "$state_home" "$sync_state_dir"; then
                echo -e "${YELLOW}Could not create chezmoi sync state directories. Skipping dotfile sync.${NC}" >&2
                return 0
        fi

        if public_source="$(chezmoi source-path 2>/dev/null)" && [ -d "$public_source" ]; then
                public_allowlist="${public_source}/docs/private-source-allowlist.txt"
                if [ -d "$private_source" ] && ! cmp -s "$public_allowlist" "$private_allowlist"; then
                        echo -e "${YELLOW}Public and private chezmoi allowlists differ. Skipping dotfile sync.${NC}" >&2
                        return 0
                fi
                sync_chezmoi_repo "Public" "$public_source" "" "$public_head" "$public_allowlist"
        else
                echo -e "${YELLOW}Public chezmoi source is unavailable. Skipping it.${NC}" >&2
        fi

        if [ ! -d "$private_source" ]; then
                echo -e "${YELLOW}Private chezmoi source is unavailable. Skipping it.${NC}" >&2
                return 0
        fi

        if ! mkdir -p "${private_state%/*}"; then
                echo -e "${YELLOW}Could not create the private chezmoi state directory. Skipping it.${NC}" >&2
                return 0
        fi

        sync_chezmoi_repo "Private" "$private_source" "$private_state" "$private_head" "$private_allowlist"
}

update_librewolf() {
        if pgrep -x librewolf >/dev/null; then
                echo -e "${YELLOW}LibreWolf is running. Skipping Arkenfox update and preference cleanup.${NC}"
                return 0
        fi

        local profiles_ini="$HOME/.librewolf/profiles.ini"
        local profile_dir
        local profile_path

        if [ ! -f "$profiles_ini" ]; then
                echo -e "${YELLOW}LibreWolf profile not found. Skipping maintenance.${NC}"
                return 0
        fi

        profile_dir=$(sed -n '/^\[Install/,/^\[/{/^Default=/{s/^Default=//p;q}}' "$profiles_ini")
        profile_path="$HOME/.librewolf/$profile_dir"

        if [ -z "$profile_dir" ] || [ ! -x "$profile_path/updater.sh" ]; then
                echo -e "${YELLOW}Arkenfox updater not found. Skipping maintenance.${NC}"
                return 0
        fi

        if [ ! -x "$profile_path/prefsCleaner.sh" ]; then
                curl -sSfL https://raw.githubusercontent.com/arkenfox/user.js/master/prefsCleaner.sh \
                        -o "$profile_path/prefsCleaner.sh" || {
                        echo -e "${YELLOW}Failed to download prefsCleaner.sh. Skipping maintenance.${NC}"
                        return 0
                }
                chmod +x "$profile_path/prefsCleaner.sh"
        fi

        (
                cd "$profile_path"
                ./updater.sh -s -n
		./prefsCleaner.sh -s -d
        )
}

update_blocklists() {
        ~/.local/bin/update_blocklists.sh 2> /dev/null || true
}

update_nchat_signal() {
        DIR="$HOME/.local/share/nchat-signal"
        mkdir -p "$DIR"
        cd "$DIR"

        curl -sSfL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=nchat-git" -o PKGBUILD || {
                echo -e "${RED}Failed to download PKGBUILD. Skipping nchat update.${NC}"
                return 1
        }

        sed -i '/-DCMAKE_INSTALL_PREFIX/i \    -DHAS_SIGNAL=ON' PKGBUILD

        if ! grep -q "HAS_SIGNAL=ON" PKGBUILD; then
                echo -e "${RED}Failed to inject Signal flag into PKGBUILD. Skipping nchat update.${NC}"
                return 1
        fi

        makepkg -od --noprepare --skipinteg --noconfirm > /dev/null 2>&1 || true

        NEW_VER=$(makepkg --printsrcinfo 2> /dev/null | awk '/pkgver =/ {print $3}' | head -n1)
        NEW_REL=$(makepkg --printsrcinfo 2> /dev/null | awk '/pkgrel =/ {print $3}' | head -n1)
        NEW_FULL="${NEW_VER}-${NEW_REL}"
        CUR_FULL=$(pacman -Q nchat-git 2> /dev/null | awk '{print $2}' || echo "None")

        if [ "$CUR_FULL" == "$NEW_FULL" ]; then
                echo -e "${BLUE}nchat-signal is up to date (${CUR_FULL}). Skipping build.${NC}"
        else
                echo -e "${GREEN}New nchat update found: ${CUR_FULL} -> ${NEW_FULL}. Building...${NC}"
                makepkg -si --noconfirm
        fi
}

remove_orphans() {
        yay -Yc --noconfirm > "/dev/null" 2>&1 || true
}

clean_caches() {
        yay -Sc --noconfirm > "/dev/null" 2>&1 || true
}

clean_temp_files() {
        sudo journalctl --vacuum-time=1d > "/dev/null" 2>&1 || true
        sudo rm -rf "${VAR_TMP_DIR:?}"/* 2> /dev/null || true
}

run_fstrim() {
        sudo fstrim -Av > "/dev/null" 2>&1 || true
}

handle_action() {
        case "${1}" in
                shutdown) systemctl poweroff ;;
                reboot) systemctl reboot ;;
        esac
}

handle_shutdown() {
        echo -e "${GREEN}The system will perform an action soon.${NC}"

        action="$(echo -e "Shutdown\nReboot\nCancel" | rofi -dmenu -i -p "Select action")"

        [[ "${action}" == "Cancel" || -z "${action}" ]] && {
                echo -e "${BLUE}Action cancelled.${NC}"
                return
        }

        delay_shutdown="$(echo -e "No\nYes" | rofi -dmenu -i -p "Do you want to delay ${action,,}?")"

        [[ "${delay_shutdown}" == "Yes" ]] && {
                while true; do
                        delay_amount="$(echo "" | rofi -dmenu -p "Enter delay amount in minutes:")"

                        [[ -z "${delay_amount}" ]] && {
                                echo -e "${action} not delayed. ${action}ing now."
                                handle_action "${action,,}"
                                break
                        }

                        [[ "${delay_amount}" =~ ^[0-9]+$ ]] || {
                                notify-send "Invalid input. Please enter a number."
                                continue
                        }

                        notify-send "${action} delayed by ${delay_amount} minutes."
                        sleep "$((delay_amount * 60))"

                        delay_shutdown="$(echo -e "No\nYes" | rofi -dmenu -i -p "Do you want to delay ${action,,} again?")"
                        [[ "${delay_shutdown}" == "No" ]] && {
                                handle_action "${action,,}"
                                break
                        }
                done
        } || { handle_action "${action,,}"; }
}

main() {
        declare -A "tasks"

        tasks["sync_chezmoi"]="Synchronize chezmoi dotfiles.
		       Chezmoi synchronization checked."

        tasks["update_mirrors"]="Update pacman mirrorlist via reflector.
		          Mirrors updated."

        tasks["update_system"]="Update Arch and AUR packages.
		       System updated."

        tasks["update_librewolf"]="Update Arkenfox and clean obsolete preferences.
			   LibreWolf profile maintained."

        tasks["update_blocklists"]="Update blocklists and trackers.
                              Blocklists updated."

        tasks["update_nchat_signal"]="Check and build nchat with Signal.
		       Nchat checked/built."

        tasks["remove_orphans"]="Remove orphan packages.
		         Orphans removed."

        tasks["clean_caches"]="Clean yay and pacman caches.
                        Caches cleaned."

        tasks["clean_temp_files"]="Clean system temporary files.
                             Temporary files cleaned."

        tasks["run_fstrim"]="Trim the filesystem.
                        Filesystem trimmed."

        task_order=("sync_chezmoi" "update_mirrors" "update_system" "update_librewolf" "update_blocklists" "update_nchat_signal" "remove_orphans"
                "clean_caches" "clean_temp_files" "run_fstrim")

        TOTAL_TASKS="${#tasks[@]}"
        TASK_NUMBER="1"

        pkill swayidle 2> /dev/null || true

        trap '[[ -n "${log_pid}" ]] && kill "${log_pid}" 2> "/dev/null"' EXIT SIGINT

        for function in "${task_order[@]}"; do
                description="${tasks[${function}]}"
                description="${description%%$'\n'*}"

                done_message="$(echo "${tasks[${function}]}" | tail -n "1" | sed 's/^[[:space:]]*//g')"

                log_info b "${description}"

                (
                        sleep "60"
                        while true; do
                                log_info c "${description}"
                                sleep "60"
                        done || true
                ) &
                log_pid="${!}"

                "${function}"
                log_info g "${done_message}"

                [[ "${TASK_NUMBER}" -eq "${TOTAL_TASKS}" ]] && {
                        log_info g "All tasks completed."
                        kill "${log_pid}" 2> "/dev/null" || true
                        break
                }

                kill "${log_pid}" 2> "/dev/null" || true

                ((TASK_NUMBER++))
        done

        if [ "${1}" = "-f" ]; then
                case "${2}" in
                        reboot) systemctl reboot ;;
                        *) systemctl poweroff ;;
                esac
        else
                "handle_shutdown"
        fi
}

main "${@}"
