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

sync_chezmoi() {
        "$HOME/.local/bin/sync_chezmoi.sh"
}

update_chezmoi_extras() {
        if ! "$HOME/.local/bin/sync_chezmoi.sh" --extras; then
                echo -e "${YELLOW}Optional chezmoi assets did not complete.${NC}" >&2
        fi
}

validate_wireguard_repo() {
	local source_dir="${1}"
	local rel

	while IFS= read -r rel || [ -n "$rel" ]; do
		case "$rel" in
			*.asc|*.conf|*/device.json|*/device-main.json|*/device-gentoo.json|*/default-relay|*/mullvad-relays.json)
				echo -e "${YELLOW}Private or runtime WireGuard file is tracked: ${rel}.${NC}" >&2
				return 1
				;;
		esac
	done < <(git -C "$source_dir" ls-files)

	if git -C "$source_dir" grep -I -E -q '(^|[^0-9])[0-9]{16}([^0-9]|$)|[A-Za-z0-9+/]{43}=' -- .; then
		echo -e "${YELLOW}Possible Mullvad account number or WireGuard key found in the public repository.${NC}" >&2
		return 1
	fi

	if [ ! -x "$source_dir/tests/test.sh" ] || ! "$source_dir/tests/test.sh"; then
		echo -e "${YELLOW}WireGuard repository tests failed.${NC}" >&2
		return 1
	fi
}

sync_wireguard() (
	local data_home source_dir
	local git_dir source_status ahead

	data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
	source_dir="${WIREGUARD_SOURCE_DIR:-$data_home/wireguard}"

	if ! command -v git >/dev/null 2>&1 || [ ! -d "$source_dir" ]; then
		echo -e "${YELLOW}WireGuard source repository is unavailable. Skipping it.${NC}" >&2
		return 0
	fi

	if ! git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
		! git -C "$source_dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
		echo -e "${YELLOW}WireGuard Git repository or upstream is not configured. Skipping it.${NC}" >&2
		return 0
	fi

	git_dir="$(git -C "$source_dir" rev-parse --absolute-git-dir)"
	if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ] ||
		[ -d "$git_dir/sequencer" ] ||
		git -C "$source_dir" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 ||
		git -C "$source_dir" rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null 2>&1 ||
		git -C "$source_dir" rev-parse -q --verify REVERT_HEAD >/dev/null 2>&1 ||
		[ -n "$(git -C "$source_dir" ls-files --unmerged)" ]; then
		echo -e "${YELLOW}A Git operation is in progress in the WireGuard repository. Skipping it.${NC}" >&2
		return 0
	fi

	if ! git -C "$source_dir" diff --cached --quiet; then
		echo -e "${YELLOW}WireGuard has staged changes. Review them manually before sync.${NC}" >&2
		return 0
	fi

	if [ -n "$(git -C "$source_dir" ls-files --others --exclude-standard)" ]; then
		echo -e "${YELLOW}WireGuard has untracked files. Review and add them manually before sync.${NC}" >&2
		return 0
	fi

	if ! validate_wireguard_repo "$source_dir"; then
		return 0
	fi

	source_status="$(git -C "$source_dir" status --porcelain --untracked-files=no)"
	if [ -n "$source_status" ]; then
		git -C "$source_dir" add -u -- .
		if ! git -C "$source_dir" diff --cached --quiet; then
			git -C "$source_dir" commit -m "Update WireGuard $(date '+%Y-%m-%d %H:%M:%S')"
		fi
	fi

	if ! git -C "$source_dir" pull --rebase; then
		if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
			git -C "$source_dir" rebase --abort || true
		fi
		echo -e "${YELLOW}WireGuard pull failed or conflicted; skipping push.${NC}" >&2
		return 0
	fi

	if ! validate_wireguard_repo "$source_dir"; then
		echo -e "${YELLOW}Pulled WireGuard changes failed validation; skipping push.${NC}" >&2
		return 0
	fi

	ahead="$(git -C "$source_dir" rev-list --count '@{upstream}..HEAD')"
	if [ "$ahead" -gt 0 ]; then
		if ! git -C "$source_dir" push; then
			echo -e "${YELLOW}WireGuard push failed. Commits remain local.${NC}" >&2
			return 0
		fi
		echo -e "${GREEN}WireGuard repository synchronized.${NC}"
	else
		echo -e "${BLUE}WireGuard repository is already synchronized.${NC}"
	fi
)

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
        local sync_failed=0

        declare -A "tasks"

        tasks["sync_chezmoi"]="Synchronize chezmoi dotfiles.
		       Chezmoi synchronization checked."

        tasks["sync_wireguard"]="Synchronize the public WireGuard repository.
			 WireGuard repository checked."

        tasks["update_chezmoi_extras"]="Refresh optional chezmoi scripts and external assets.
				  Optional chezmoi assets checked."

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

	task_order=("sync_chezmoi" "sync_wireguard" "update_chezmoi_extras" "update_mirrors" "update_system" "update_librewolf" "update_blocklists" "update_nchat_signal" "remove_orphans"
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

                if [ "$function" = "sync_chezmoi" ]; then
                        if "$function"; then
                                log_info g "$done_message"
                        else
                                sync_failed=1
                                log_info r "Chezmoi sync needs attention; maintenance will continue."
                        fi
                else
                        "${function}"
                        log_info g "${done_message}"
                fi

                [[ "${TASK_NUMBER}" -eq "${TOTAL_TASKS}" ]] && {
                        if [ "$sync_failed" -eq 1 ]; then
                                log_info r "Maintenance tasks finished; Chezmoi sync remains incomplete."
                        else
                                log_info g "All tasks completed."
                        fi
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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        main "$@"
fi
