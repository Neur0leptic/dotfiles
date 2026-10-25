#!/bin/bash
# sms - System, Maintain, Shutdown (Gentoo version)

[ "$(id -u)" -eq "0" ] && {
        echo -e "\e[1;91mThis script must NOT be run as root on Gentoo.\e[0m" >&2
        echo "Commands that need root run through doas." >&2
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

KERNEL_PATH="/boot/EFI/BOOT/BOOTX64.EFI"

# The running kernel's configuration, one folder per machine, so a reinstall can start from a
# configuration this machine has booted with.
KERNEL_CONFIGS_REPO="git@github.com:Neur0leptic/kernel-configs.git"
KERNEL_CONFIGS_DIR="${HOME}/.local/share/kernel-configs"

MODULES_DIR="/lib/modules"
USER_CACHE_DIR="${HOME}/.cache"
VAR_TMP_DIR="/var/tmp"

FAILED_LOG_DIR="${USER_CACHE_DIR}/failed_builds"
FAILED_PACKAGES="${USER_CACHE_DIR}/failed_packages.txt"

# LibreWolf takes hours to build and nodejs is only its build dependency, so the world
# update leaves both for "sms --librewolf".
LONG_BUILDS=("www-client/librewolf" "net-libs/nodejs")
WITH_LONG_BUILDS="0"
FORCED_ACTION=""

renew_env() {
        doas env-update && source "/etc/profile"
}

sync_chezmoi() {
        "$HOME/.local/bin/sync_chezmoi.sh"
}

update_chezmoi_extras() {
        if ! "$HOME/.local/bin/sync_chezmoi.sh" --extras; then
                echo -e "${YELLOW}Optional chezmoi assets did not complete.${NC}" >&2
        fi
}

update_wireguard_scripts() {
        # Root's copies for the boot service, as the installer made them. They follow the
        # checkout only while it is unmodified and at its upstream, that is, published.
        local source_dir="${XDG_DATA_HOME:-$HOME/.local/share}/wireguard"
        local pair repo_file target

        [ -f "/usr/local/bin/wireguard.sh" ] && [ -d "${source_dir}/.git" ] || {
                echo -e "${BLUE}No WireGuard scripts to update.${NC}"
                return 0
        }

        if ! git -C "${source_dir}" diff --quiet HEAD -- 2> "/dev/null" ||
                [ "$(git -C "${source_dir}" rev-parse HEAD 2> "/dev/null")" != \
                        "$(git -C "${source_dir}" rev-parse '@{upstream}' 2> "/dev/null")" ]; then
                echo -e "${YELLOW}The WireGuard checkout is modified or not at its upstream. Keeping root's copies.${NC}" >&2
                return 0
        fi

        for pair in "bin/wireguard.sh:/usr/local/bin/wireguard.sh" \
                "libexec/wireguard-dns.sh:/usr/local/bin/wireguard-dns.sh" \
                "init/openrc/wireguard-autoconnect:/etc/init.d/wireguard-autoconnect"; do
                repo_file="${source_dir}/${pair%%:*}"
                target="${pair#*:}"
                [ -f "${repo_file}" ] && [ -f "${target}" ] || continue
                ! cmp -s "${repo_file}" "${target}" || continue
                sh -n "${repo_file}" || {
                        echo -e "${YELLOW}${repo_file} does not parse. Keeping ${target}.${NC}" >&2
                        continue
                }
                doas install -m "0755" "${repo_file}" "${target}"
                echo -e "${GREEN}Updated ${target}.${NC}"
        done
}

sync_repos() {
        doas emaint sync -a > "/dev/null" 2>&1
}

update_world() {
        local package
        local -a excluded=()

        if [ "${WITH_LONG_BUILDS}" -eq "0" ]; then
                for package in "${LONG_BUILDS[@]}"; do
                        excluded+=("--exclude" "${package}")
                done
        fi

        doas emerge --update --newuse "@world" "${excluded[@]}" 2>&1 || true
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

update_live() {
        return "0"
        doas emerge "@live-rebuild" 2>&1 || true
}

remove_unneeded() {
        doas emerge --depclean > "/dev/null" 2>&1 || true
}

create_logs() {
        rm -rfv "${FAILED_LOG_DIR}"
        mkdir -p "${FAILED_LOG_DIR}"
        # The log file will be created by script -c -q command.
        [ -f "${HOME}/output.log" ] && {
                grep -oP 'Failed to emerge \K[[:alnum:]_-]+/[[:alnum:]._-]+' "${HOME}/output.log" > "${FAILED_PACKAGES}"
                rm -rfv "${HOME}/output.log"
        } || true
}

root_make() {
        # doas gives root a clean environment, so the kernel build's LLVM, LLVM_IAS and
        # CFLAGS are passed explicitly; clang's directory (/usr/lib/llvm/SLOT/bin) is only
        # in the profile's PATH.
        doas env LLVM="${LLVM}" LLVM_IAS="${LLVM_IAS}" CFLAGS="${CFLAGS}" \
                sh -c '. /etc/profile.env && exec make "$@"' make "$@"
}

backup_kernel_config() {
        # Runs before update_kernel, so the configuration of the kernel this machine booted is
        # on GitHub before a build replaces it. Failures only warn: maintenance must go on.
        local repo="${KERNEL_CONFIGS_DIR}" running tree build_dir="" field="product_name"
        local machine package use ahead

        # update_world may already have pointed /usr/src/linux at new sources that are not built
        # yet, so look for the tree whose last build is the running kernel.
        running="$(uname -v)"
        for tree in $(find /usr/src/ -maxdepth "1" -type d -name 'linux-*' ! -name '*-dist'); do
                [ -f "${tree}/include/generated/utsversion.h" ] || continue
                if [ "$(sed -n 's/^#define UTS_VERSION "\(.*\)"$/\1/p' "${tree}/include/generated/utsversion.h")" = "${running}" ]; then
                        build_dir="${tree}"
                        break
                fi
        done

        [ -n "${build_dir}" ] || {
                echo -e "${BLUE}The running kernel was not built from a source tree in /usr/src. Nothing to back up.${NC}"
                return 0
        }

        # A .config changed after that build belongs to a kernel that has not booted yet.
        [ "${build_dir}/.config" -ot "${build_dir}/include/generated/utsversion.h" ] || {
                echo -e "${YELLOW}${build_dir}/.config changed after the running kernel was built. The repository keeps the configuration that last booted.${NC}"
                return 0
        }

        if [ ! -d "${repo}/.git" ] && ! git clone -q \
                -c core.sshCommand="ssh -i ${HOME}/.ssh/id_ed25519_github -o IdentitiesOnly=yes" \
                -c user.name="Neur0leptic" -c user.email="61053005+Neur0leptic@users.noreply.github.com" \
                "${KERNEL_CONFIGS_REPO}" "${repo}"; then
                echo -e "${YELLOW}Could not clone ${KERNEL_CONFIGS_REPO}. The next run tries again.${NC}" >&2
                return 0
        fi

        # Lenovo keeps the model name ("ThinkPad X220") in product_version.
        [ "$(cat /sys/class/dmi/id/sys_vendor 2> "/dev/null")" != "LENOVO" ] || field="product_version"
        machine="$(cat "/sys/class/dmi/id/${field}" 2> "/dev/null")" || true
        machine="${machine:-${HOSTNAME}}"
        machine="$(echo "${machine,,}" | tr -cs '[:alnum:]' '-')"
        machine="${machine#-}"
        machine="${machine%-}"

        package="$(portageq owners / "${build_dir}" 2> "/dev/null" | head -n "1")" || true
        [ -z "${package}" ] || use="$(cat "/var/db/pkg/${package}/USE" 2> "/dev/null")" || true

        mkdir -p "${repo}/${machine}" &&
                cp -f "${build_dir}/.config" "${repo}/${machine}/config" &&
                printf 'kernel:  %s %s\nsources: %s\n' "$(uname -r)" "${running}" \
                        "${package:-unknown}${use:+ (USE: ${use})}" > "${repo}/${machine}/info" || {
                echo -e "${YELLOW}Could not copy the kernel configuration to ${repo}.${NC}" >&2
                return 0
        }

        if [ -n "$(git -C "${repo}" status --porcelain -- "${machine}")" ]; then
                git -C "${repo}" add -- "${machine}" &&
                        git -C "${repo}" commit -q -m "${machine}: $(uname -r) ${running}" || {
                        echo -e "${YELLOW}Could not commit the kernel configuration in ${repo}.${NC}" >&2
                        return 0
                }
        fi

        # This also pushes a commit that an earlier run could not push.
        if ! ahead="$(git -C "${repo}" rev-list --count '@{upstream}..HEAD' 2> "/dev/null")"; then
                echo -e "${YELLOW}${repo} has no upstream branch; is the GitHub repository empty? Nothing was pushed.${NC}" >&2
        elif [ "${ahead}" -eq "0" ]; then
                echo -e "${BLUE}GitHub already has the running kernel's configuration.${NC}"
        elif git -C "${repo}" pull -q --rebase && git -C "${repo}" push -q; then
                echo -e "${GREEN}The running kernel's configuration is on GitHub in ${machine}/.${NC}"
        else
                echo -e "${YELLOW}Could not push the kernel configuration. The next run tries again.${NC}" >&2
        fi
}

update_kernel() {
        # Custom kernels only: a distribution kernel's tree ends in "-dist" and belongs to its
        # package, which also installs the kernel.
        DIR_COUNT="$(find /usr/src/ -maxdepth "1" -type d -name 'linux-*' ! -name '*-dist' | wc -l)"

        [ "${DIR_COUNT}" -gt "1" ] || {
                echo -e "${BLUE}There is only one linux directory. The function stops...${NC}"
                KERNEL_IS_UPDATED="0"
                return
        }

        KERNEL_DIR="$(find /usr/src/ -maxdepth "1" -type d -name 'linux-*' ! -name '*-dist' | sort -rV | head -n "1")"

        echo -e "${GREEN}Your new kernel directory:${CYAN} ${KERNEL_DIR} ${NC}"

        OLD_KERNEL_DIR="$(find /usr/src/ -maxdepth "1" -type d -name 'linux-*' ! -name '*-dist' | sort -rV | head -n "2" | tail -n "1")"

        echo -e "${GREEN}Your old kernel directory:${CYAN} ${OLD_KERNEL_DIR} ${NC}"

        export LLVM="1" LLVM_IAS="1" CFLAGS="-O3 -march=native -pipe"

        # Only a fresh source tree inherits the old configuration; never overwrite a prepared one.
        [ -f "${KERNEL_DIR}/.config" ] || doas cp -fv "${OLD_KERNEL_DIR}/.config" "${KERNEL_DIR}"

        root_make -C "${KERNEL_DIR}" "olddefconfig" > "/dev/null" 2>&1
        root_make -C "${KERNEL_DIR}" -j"$(nproc)" > "/dev/null" 2>&1
        if grep -qx 'CONFIG_MODULES=y' "${KERNEL_DIR}/.config"; then
                root_make -C "${KERNEL_DIR}" "modules_install" > "/dev/null" 2>&1
        fi

        # The firmware boots only BOOTX64.EFI: keep the old image and replace it in one rename,
        # so a failed build or a full ESP never leaves a half-written kernel behind.
        [ -s "${KERNEL_DIR}/arch/x86/boot/bzImage" ]
        ! doas test -f "${KERNEL_PATH}" || doas cp -fv "${KERNEL_PATH}" "${KERNEL_PATH}.old"
        doas cp -f "${KERNEL_DIR}/arch/x86/boot/bzImage" "${KERNEL_PATH}.new"
        doas mv -f "${KERNEL_PATH}.new" "${KERNEL_PATH}"

        echo -e "${GREEN}Your new kernel${CYAN} ${KERNEL_DIR}/arch/x86/boot/bzImage ${GREEN}has been copied to${CYAN} ${KERNEL_PATH}.${NC}"

        doas rm -rf "${OLD_KERNEL_DIR}"

        echo -e "${GREEN}Your old kernel directory${CYAN} ${OLD_KERNEL_DIR} ${GREEN}has been deleted.${NC}"
}

update_nvidia() {
        grep -q 'VIDEO_CARDS="nvidia"' "/etc/portage/make.conf" || {
                echo "Not using Nvidia GPU."
                return
        }
        [[ "${KERNEL_IS_UPDATED}" == "0" ]] && {
                echo -e "${BLUE}The kernel has not been updated. Skipping Nvidia drivers...${NC}"
                return
        }
        doas emerge "x11-drivers/nvidia-drivers" > "/dev/null" 2>&1
}

copy_failed_logs() {
        [ -f "${FAILED_PACKAGES}" ] || return 0

        while IFS= read -r pkg; do
                log_path="/var/tmp/portage/${pkg}/temp/build.log"
                safe_pkg_name="$(echo "${pkg}" | tr '/' '_')"
                doas test -f "${log_path}" && doas cp "${log_path}" "${FAILED_LOG_DIR}/${safe_pkg_name}.log"
        done < "${FAILED_PACKAGES}"

        doas chown -vR "$(id -un)":"$(id -gn)" "${FAILED_LOG_DIR}"
}

clean_old_modules() {
        # Custom kernels only; a distribution kernel's modules belong to its package.
        find "${MODULES_DIR}" -mindepth "1" -maxdepth "1" -type "d" ! -name '*-dist' | sort -V | head -n "-1" | xargs -r doas rm -rf
}

clean_temp_files() {
        # Downloaded sources and build leftovers only: the rest of /var/cache holds Portage's
        # state and WireGuard's relay list, and /var/log the build history.
        local distdir

        distdir="$(portageq distdir)"
        doas rm -rf "${distdir:?}"/* "${VAR_TMP_DIR:?}"/*
}

run_fstrim() {
        doas fstrim -Av
}

check_librewolf_update() {
        local installed available

        [ "${WITH_LONG_BUILDS}" -eq "0" ] || return 0

        installed="$(portageq match / "www-client/librewolf" 2> "/dev/null" | tail -n "1")" || true
        available="$(portageq best_visible / "www-client/librewolf" 2> "/dev/null")" || true

        if [ -n "${installed}" ] && [ -n "${available}" ] && [ "${installed}" != "${available}" ]; then
                echo -e "${YELLOW}${available#www-client/} is available (installed: ${installed#www-client/}). It builds for hours; run ${CYAN}sms --librewolf${YELLOW} when there is time.${NC}"
        else
                echo -e "${BLUE}No LibreWolf update is waiting.${NC}"
        fi
}

handle_action() {
        case "${1}" in
                shutdown) doas openrc-shutdown -p "now" ;;
                reboot) doas openrc-shutdown -r "now" ;;
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

        while [ "$#" -gt "0" ]; do
                case "${1}" in
                        --librewolf) WITH_LONG_BUILDS="1" ;;
                        -f)
                                FORCED_ACTION="shutdown"
                                [ "${2:-}" != "reboot" ] || {
                                        FORCED_ACTION="reboot"
                                        shift
                                }
                                ;;
                        *)
                                echo "Usage: sms [--librewolf] [-f [reboot]]" >&2
                                exit 1
                                ;;
                esac
                shift
        done

        declare -A "tasks"

        tasks["renew_env"]="Renew the environment.
		       Environment renewed."

        tasks["sync_chezmoi"]="Synchronize chezmoi dotfiles.
		       Chezmoi synchronization checked."

        tasks["update_chezmoi_extras"]="Refresh optional chezmoi scripts and external assets.
				  Optional chezmoi assets checked."

        tasks["update_wireguard_scripts"]="Update root's copies of the WireGuard scripts.
				     WireGuard scripts checked."

        tasks["sync_repos"]="Sync the Gentoo repositories.
		       Gentoo repositories synced."

        tasks["update_world"]="Update the world.
		         The world updated."

        tasks["update_librewolf"]="Update Arkenfox and clean obsolete preferences.
			   LibreWolf profile maintained."

        tasks["update_live"]="Update live packages.
                        Live packages updated."

        tasks["remove_unneeded"]="Remove unneeded packages.
                            Unneeded packages removed."

        tasks["create_logs"]="Create logs for failed packages.
                        Logs for failed packages created."

        tasks["backup_kernel_config"]="Back up the running kernel's configuration to GitHub.
                                 Kernel configuration backup checked."

        tasks["update_kernel"]="Update the custom kernel.
		          The kernel is ready."

        tasks["update_nvidia"]="Recompile Nvidia drivers.
		          Nvidia drivers ready."

        tasks["copy_failed_logs"]="Copy failed build logs.
		             Failed build logs copied."

        tasks["clean_old_modules"]="Clean old kernel modules.
			      Old kernel modules cleaned."

        tasks["clean_temp_files"]="Clean downloaded sources and temporary files.
                             Temporary files cleaned."

        tasks["run_fstrim"]="Trim the filesystem.
                        Filesystem trimmed."

        tasks["check_librewolf_update"]="Check for a LibreWolf update to build separately.
				   LibreWolf update checked."

        task_order=("renew_env" "sync_chezmoi" "update_chezmoi_extras" "update_wireguard_scripts"
                "sync_repos" "update_world" "update_librewolf" "update_live" "remove_unneeded"
                "create_logs" "backup_kernel_config" "update_kernel" "update_nvidia" "copy_failed_logs"
                "clean_old_modules" "clean_temp_files" "run_fstrim" "check_librewolf_update")

        TOTAL_TASKS="${#tasks[@]}"
        TASK_NUMBER="1"

        pkill swayidle 2> /dev/null || true

        # The status line process is usually gone already; that is not an error.
        trap '[[ -z "${log_pid}" ]] || kill "${log_pid}" 2> "/dev/null" || true' EXIT SIGINT

        for function in "${task_order[@]}"; do
                description="${tasks[${function}]}"
                description="${description%%$'\n'*}"

                done_message="$(echo "${tasks[${function}]}" | tail -n "1" | sed 's/^[[:space:]]*//g')"

                log_info b "${description}"

                (
                        sleep "120"
                        while true; do
                                log_info c "${description}"
                                sleep "120"
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

        if [ -n "${FORCED_ACTION}" ]; then
                handle_action "${FORCED_ACTION}"
        else
                "handle_shutdown"
        fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        main "$@"
fi
