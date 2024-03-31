#!/bin/dash

REPO_DIR="${XDG_DATA_HOME}/sharedrepo"
REPO_BRANCH="main"

SELECTED="
	${HOME}/.local/bin
	${HOME}/.config
"

EXCLUDED="
	${HOME}/.config/BraveSoftware
	${HOME}/.config/btop
	${HOME}/.config/coc
	${HOME}/.config/dconf
	${HOME}/.config/dunst
	${HOME}/.config/libreoffice
	${HOME}/.config/msmtp
	${HOME}/.config/mutt
	${HOME}/.config/Prowlarr
	${HOME}/.config/pulse
	${HOME}/.config/qt6ct
	${HOME}/.config/transmission
	${HOME}/.config/transmission-daemon
	${HOME}/.config/WebCord
	${HOME}/.config/zsh/fast-syntax-highlighting
	${HOME}/.config/zsh/fzf-tab
	${HOME}/.config/zsh/powerlevel10k
	${HOME}/.config/zsh/.zcompdump
	${HOME}/.config/zsh/zsh-autosuggestions
	${HOME}/.config/.mymlocate.db
	${HOME}/.config/notmuch-config
	${HOME}/.config/QtProject.conf
	${HOME}/.config/nvim/autoload
	${HOME}/.config/nvim/coc-settings.json
	${HOME}/.config/nvim/plugged
	${HOME}/.config/mpv
	${HOME}/.config/syncplay.ini
	${HOME}/.local/bin/Telegram
	${HOME}/.local/bin/Updater
	${HOME}/.local/bin/ab-av1
	${HOME}/.local/bin/av1an
	${HOME}/.local/bin/lf
	${HOME}/.local/bin/ssimulacra2_rs
	${HOME}/.local/bin/movie.py
	${HOME}/.local/bin/squashfs-root
	${HOME}/.local/bin/tgpt
	${HOME}/.local/bin/tspdt_rankings.xlsx
"

print() {
	printf '%s\n' "${1}"
}

sync() {
	rsync -avzh --delete --progress --itemize-changes "${1}" "${2}"
}

is_excluded() {
	for exclude in ${EXCLUDED}; do
		case "${1}" in
			"${exclude}"*) return "0" ;;
		esac
	done
	return "1"
}

iterate_files() {
	src="${1}"
	dest="${2}"


	for dir in ${SELECTED}; do
		[ -d "${src}/${dir#"${HOME}"/}" ] || continue

		find "${src}/${dir#"${HOME}"/}" -type f | while IFS= read -r file; do
			rel_path="${file#"${src}"/}"

			is_excluded "${HOME}/${rel_path}" && continue

			[ "${file}" -nt "${dest}/${rel_path}" ] || [ ! -e "${dest}/${rel_path}" ] && {
				mkdir -pv "${dest}/$(dirname "${rel_path}")"
				sync "${file}" "${dest}/${rel_path}"
			}
		done
	done
}

copy_files() {
	iterate_files "${HOME}" "${REPO_DIR}"
}

push() {
	copy_files

	for dir in ${SELECTED}; do
		[ -d "${REPO_DIR}/${dir#"${HOME}"/}" ] || continue

		find "${REPO_DIR}/${dir#"${HOME}"/}" -type f | while IFS= read -r file; do
			rel_path="${file#"${REPO_DIR}"/}"

			[ -e "${HOME}/${rel_path}" ] || {
			        git -C "${REPO_DIR}" rm --cached "${rel_path}"
			        rm -rfv "${file}"
			}
		done
	done

	git -C "${REPO_DIR}" add .

	git -C "${REPO_DIR}" diff-index --quiet HEAD && {
	        print 'No changes to commit.'
	        exit "0"
	} || {
	        print "ENTER COMMIT MESSAGE: "
	        read -r message
	        git -C "${REPO_DIR}" commit -m "${message}"
	        git -C "${REPO_DIR}" push origin "${REPO_BRANCH}"
	}
}

merge() {
	git -C "${REPO_DIR}" pull --rebase origin "${REPO_BRANCH}"
	iterate_files "${REPO_DIR}" "${HOME}"
}

dry_push() {
	for dir in ${SELECTED}; do
		[ -d "${HOME}/${dir#"${HOME}"/}" ] || continue

		while IFS= read -r file; do
		        rel_path="${file#"${HOME}"/}"

		        is_excluded "${file}" && continue

		        [ "${file}" -nt "${REPO_DIR}/${rel_path}" ] && {
		                diff -u --color=always "${REPO_DIR}/${rel_path}" "${file}" | less
		                printf '\n'
		                changes="1"
		        }

		        [ ! -e "${REPO_DIR}/${rel_path}" ] && {
		                diff -u --color=always "/dev/null" "${file}" | less
		                printf '\n'
		                changes="1"
		        }
		done << EOF
$(find "${HOME}/${dir#"${HOME}"/}" -type f)
EOF

		while IFS= read -r file; do
		        rel_path="${file#"${REPO_DIR}"/}"

		        is_excluded "${HOME}/${rel_path}" && continue

		        [ ! -e "${HOME}/${rel_path}" ] && {
		                printf 'Removed file: %s\n\n' "${HOME}/${rel_path}"
		                changes="1"
		        }
		done << EOF
$(find "${REPO_DIR}/${dir#"${HOME}"/}" -type f)
EOF
	done

	[ -z "${changes}" ] && printf 'No changes to commit.\n'
}

dry_merge() {
	git -C "${REPO_DIR}" fetch origin "${REPO_BRANCH}"

    	{ git -C "${REPO_DIR}" diff --quiet HEAD "origin/${REPO_BRANCH}" && printf 'Already up to date.\n'; } || {
        	printf 'Changes detected. Reviewing diff:\n\n'
        	git -C "${REPO_DIR}" diff --color=always HEAD "origin/${REPO_BRANCH}" | less
    	}

	for dir in ${SELECTED}; do
		[ -d "${REPO_DIR}/${dir#"${HOME}"/}" ] || continue

		while IFS= read -r file; do
			rel_path="${file#"${REPO_DIR}"/}"

			is_excluded "${HOME}/${rel_path}" && continue

			[ -e "${HOME}/${rel_path}" ] && {
				[ "${file}" -nt "${HOME}/${rel_path}" ] &&
				printf 'Updated file: %s\n' "${HOME}/${rel_path}"
				continue
			}

			printf 'New file: %s\n' "${HOME}/${rel_path}"
		done << EOF
$(find "${REPO_DIR}/${dir#"${HOME}"/}" -type f)
EOF
	done
}

print_help() {
	printf '%s\n%s\n%s\n%s\n%s\n' \
	'-p, --push : Push the changes' \
	'-m, --merge : Merge the changes' \
	'-dp, --dry-push : Dry run for testing' \
	'-dm, --dry-merge : Dry run for testing' \
	'-h, --help : Print this message' >&2
	exit "0"
}

main() {
	[ "${#}" -eq "0" ] && print_help

	[ -d "${REPO_DIR}" ] || {
	        print "You do not have the repository."
	        exit "1"
	}

	case "${1}" in
	        "-p"|"--push") push ;;
	        "-m"|"--merge") merge ;;
	        "-h"|"--help") print_help ;;
	        "-dp"|"--dry-push") dry_push ;;
	        "-dm"|"--dry-merge") dry_merge ;;
	        *) print "Invalid option: ${1}" >&2; print_help ;;
	esac
}

main "${@}"
