#!/bin/sh

set -eu

[ "$#" -le 1 ] || { printf 'usage: update_dwl.sh [--no-restart|--prepare-config]\n' >&2; exit 2; }
prepare_only=0
restart=1
case "${1:-}" in
    "") ;;
    --prepare-config) prepare_only=1; restart=0 ;;
    --no-restart) restart=0 ;;
    --help)
        printf 'Edit ~/.local/src/dwl/config.h, then run update_dwl.sh [--no-restart].\n'
        exit 0 ;;
    *) printf 'usage: update_dwl.sh [--no-restart|--prepare-config]\n' >&2; exit 2 ;;
esac

config="$HOME/.local/src/dwl/config.h"
[ -f "$config" ] && [ ! -L "$config" ] &&
    [ "$(readlink -m -- "$config")" = "$config" ] &&
    [ "$(stat -c %u "$config")" = "$(id -u)" ] &&
    [ $((0$(stat -c %a "$config") & 022)) -eq 0 ] &&
    grep -qxF '#define DWL_CONFIG_VERSION 1' "$config" || {
    printf 'Review the native DWL settings at %s first; existing files were preserved.\n' "$config" >&2
    exit 1
}

terminate_dwl() {
    if [ "$restart" -eq 1 ] && pgrep -x -u "$(id -u)" dwl >/dev/null 2>&1; then
        pkill -TERM -x -u "$(id -u)" dwl
    fi
}

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
fi

prepare_savedconfig() (
    cache="${XDG_CACHE_HOME:-$HOME/.cache}"
    mkdir -p "$cache"
    snapshot=$(mktemp "$cache/dwl-config.XXXXXX")
    trap 'rm -f -- "$snapshot"' 0
    trap 'exit 130' 1 2 15
    cp -- "$config" "$snapshot"
    cmp -s "$config" "$snapshot" || { printf 'config.h changed during preparation.\n' >&2; exit 1; }
    chmod 0644 "$snapshot"
    host=$(portageq envvar CHOST)
    target=$(portageq envvar CTARGET 2>/dev/null || true)
    doas sh -s -- "$snapshot" "$host" "$target" <<'ROOT'
set -eu
snapshot=$1
base=/etc/portage/savedconfig
installed=/usr/share/dwl/neurogentoo/config.h
backups=/var/lib/install-system/dwl-backups
[ "$(readlink -m -- "$base")" = "$base" ] && [ ! -L "$base/gui-wm" ] || { printf 'Unsafe savedconfig root.\n' >&2; exit 1; }
[ "$(readlink -m -- "$backups")" = "$backups" ] || exit 1
[ ! -e "$backups" ] || [ "$(stat -c %u "$backups")" = "$(id -u)" ] || exit 1
install -d -m 0700 "$backups"
[ ! -L "$backups/update.lock" ] || exit 1
exec 9>"$backups/update.lock"
flock -n 9 || { printf 'Another DWL config update is running.\n' >&2; exit 1; }
temporary=""
trap '[ -z "$temporary" ] || rm -f -- "$temporary"' 0
trap 'exit 130' 1 2 15
prepared="$backups/last-prepared-config.h"
pending="$backups/pending-config.h"
for receipt in "$prepared" "$pending"; do
    [ ! -e "$receipt" ] && [ ! -L "$receipt" ] && continue
    [ -f "$receipt" ] && [ ! -L "$receipt" ] &&
        [ "$(stat -c %u "$receipt")" = "$(id -u)" ] || exit 1
done
if [ -f "$pending" ] && ! cmp -s "$snapshot" "$pending"; then
    printf 'An interrupted DWL handoff remains at %s. Finish/reconcile that input before preparing a different header; originals were retained.\n' "$pending" >&2
    exit 1
fi
known_config() {
    cmp -s "$1" "$snapshot" ||
        { [ -f "$installed" ] && cmp -s "$1" "$installed"; } ||
        { [ -f "$prepared" ] && cmp -s "$1" "$prepared"; }
}
set -- "" "$2" "$3"
for prefix; do
    case "$prefix" in .|..|*[!a-zA-Z0-9._-]*) printf 'Unsafe Portage target prefix.\n' >&2; exit 1 ;; esac
    [ -z "$prefix" ] || [ ! -L "$base/$prefix" ] || { printf 'Unsafe savedconfig prefix.\n' >&2; exit 1; }
    directory="$base${prefix:+/$prefix}/gui-wm"
    [ ! -L "$directory" ] || { printf 'Savedconfig directory is a symlink: %s\n' "$directory" >&2; exit 1; }
    for file in "$directory/dwl" "$directory/dwl-9999" "$directory"/._cfg????_dwl "$directory"/._cfg????_dwl-9999; do
        [ -e "$file" ] || [ -L "$file" ] || continue
        [ -f "$file" ] && [ ! -L "$file" ] || { printf 'Unsafe savedconfig: %s\n' "$file" >&2; exit 1; }
        if ! known_config "$file"; then
            printf 'Conflicting native DWL edit was preserved: %s\n' "$file" >&2
            exit 1
        fi
    done
done
# Root retains the exact last handoff, so a fix after a failed build is retryable.
# A pending handoff is completed with the same input before accepting another one.
if [ ! -f "$pending" ]; then
    temporary=$(mktemp "$backups/.prepared.XXXXXX")
    install -m 0600 "$snapshot" "$temporary"
    mv -T -- "$temporary" "$pending"
    temporary=""
fi
snapshot="$pending"
replace_config() {
    file=$1
    if [ -e "$file" ] || [ -L "$file" ]; then
        [ -f "$file" ] && [ ! -L "$file" ] || exit 1
        cmp -s "$file" "$snapshot" && return 0
        known_config "$file" || {
            printf 'DWL savedconfig changed during preparation: %s\n' "$file" >&2; exit 1
        }
        backup=$(mktemp "$backups/$(basename "$file").XXXXXX")
        cp -p -- "$file" "$backup"
        printf '%s\n' "$file" > "$backup.path"
        chmod 0600 "$backup.path"
        cmp -s "$file" "$backup" || { printf 'DWL savedconfig changed during backup.\n' >&2; exit 1; }
        temporary=$(mktemp "$(dirname "$file")/.dwl.XXXXXX")
        install -m 0644 "$snapshot" "$temporary"
        cmp -s "$file" "$backup" || { printf 'DWL savedconfig changed before replacement.\n' >&2; exit 1; }
        mv -T -- "$temporary" "$file"
    else
        temporary=$(mktemp "$(dirname "$file")/.dwl.XXXXXX")
        install -m 0644 "$snapshot" "$temporary"
        ln -- "$temporary" "$file" || { printf 'DWL savedconfig appeared during preparation.\n' >&2; exit 1; }
        rm -f -- "$temporary"
    fi
    temporary=""
}
# Inspect all candidates before changing any of them; retain every replaced original.
for prefix; do
    directory="$base${prefix:+/$prefix}/gui-wm"
    for file in "$directory/dwl" "$directory/dwl-9999" "$directory"/._cfg????_dwl "$directory"/._cfg????_dwl-9999; do
        [ -f "$file" ] || continue
        replace_config "$file"
    done
done
install -d -m 0755 "$base/gui-wm"
replace_config "$base/gui-wm/dwl"
mv -T -- "$pending" "$prepared"
ROOT
    cmp -s "$config" "$snapshot" || { printf 'config.h changed during preparation; retry before building.\n' >&2; exit 1; }
)

if [ "$prepare_only" -eq 1 ]; then
    case "${ID:-} ${ID_LIKE:-}" in
        *gentoo*) prepare_savedconfig ;;
        *arch*) ;;
        *) printf 'Unsupported DWL package platform.\n' >&2; exit 1 ;;
    esac
    exit 0
fi

update_packaged_dwl() (
    patch="${XDG_CONFIG_HOME:-$HOME/.config}/dwl/patches/0001-neuroleptic.patch"
    protocol="${XDG_CONFIG_HOME:-$HOME/.config}/dwl/protocols/dwl-ipc-unstable-v2.xml"
    provenance=/usr/share/dwl/neurogentoo
    [ -r "$provenance/default-config.h" ] || {
        printf 'The installed DWL package needs the reviewed single-header migration first; no package was changed.\n' >&2
        exit 1
    }
    [ -r "$patch" ] && [ -r "$protocol" ] || {
        printf 'Synchronize the DWL patch/protocol with the existing Chezmoi sync script first.\n' >&2
        exit 1
    }
    if cmp -s "$patch" "$provenance/desktop.patch" && cmp -s "$protocol" "$provenance/dwl-ipc-unstable-v2.xml" &&
        cmp -s "$config" "$provenance/config.h"; then
        printf 'DWL already matches config.h and its feature inputs; no rebuild needed.\n'
        exit 0
    fi
    if cmp -s "$patch" "$provenance/desktop.patch" && cmp -s "$protocol" "$provenance/dwl-ipc-unstable-v2.xml"; then
        # A header-only rebuild uses the package's existing published feature inputs.
        ref=$(cat "$provenance/dotfiles-revision")
        case "$ref" in *[!0-9a-f]*|'') exit 1 ;; esac
        [ "${#ref}" -eq 40 ] || exit 1
    else
        source=$(chezmoi source-path)
        origin=$(git -C "$source" remote get-url origin)
        case "$origin" in
            https://github.com/Neur0leptic/dotfiles.git|git@github.com:Neur0leptic/dotfiles.git) ;;
            *) printf 'Unexpected public dotfiles origin; no package was changed.\n' >&2; exit 1 ;;
        esac
        [ "$(git -C "$source" symbolic-ref --quiet --short HEAD)" = main ] &&
            [ "$(git -C "$source" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')" = origin/main ] &&
            [ -z "$(git -C "$source" status --porcelain --untracked-files=all)" ] &&
            git -C "$source" merge-base --is-ancestor HEAD origin/main || {
            printf 'Use the existing Chezmoi sync workflow to publish/reconcile feature inputs before rebuilding DWL.\n' >&2
            exit 1
        }
        ref=$(git -C "$source" rev-parse HEAD)
        git -C "$source" show "$ref:dot_config/dwl/patches/0001-neuroleptic.patch" | cmp -s "$patch" - &&
            git -C "$source" show "$ref:dot_config/dwl/protocols/dwl-ipc-unstable-v2.xml" | cmp -s "$protocol" - || {
            printf 'The deployed patch/protocol differs from the synchronized source; no package was changed.\n' >&2
            exit 1
        }
    fi
    case "${ID:-} ${ID_LIKE:-}" in
        *gentoo*)
            portageq has_version / 'gui-wm/dwl[savedconfig]' || {
                printf 'DWL needs package-specific savedconfig support; no package was changed.\n' >&2
                exit 1
            }
            prepare_savedconfig
            doas env "EGIT_OVERRIDE_COMMIT_NEUR0LEPTIC_DOTFILES=$ref" \
                emerge --oneshot --keep-going=n '=gui-wm/dwl-9999::neurogentoo'
            ;;
        *arch*)
            [ -r "$provenance/PKGBUILD" ] && grep -qF 'DWL_CONFIG_FILE' "$provenance/PKGBUILD" || {
                printf 'The installed DWL package lacks its live PKGBUILD; update it through the installer first.\n' >&2
                exit 1
            }
            builddir=$(mktemp -d "${TMPDIR:-/tmp}/dwl-package.XXXXXX")
            trap 'rm -rf -- "$builddir"' 0
            trap 'exit 130' 1 2 15
            cp "$provenance/PKGBUILD" "$builddir/PKGBUILD"
            cp "$config" "$builddir/config.h"
            cd "$builddir"
            DWL_DOTFILES_REF="$ref" DWL_CONFIG_FILE="$builddir/config.h" makepkg --syncdeps --install --clean --force
            ;;
        *) printf 'Unsupported distribution for packaged DWL update.\n' >&2; exit 1 ;;
    esac
    cmp -s "$patch" "$provenance/desktop.patch" && cmp -s "$protocol" "$provenance/dwl-ipc-unstable-v2.xml" &&
        cmp -s "$config" "$provenance/config.h" || {
        printf 'Rebuilt DWL differs from config.h or its feature inputs; the session was not stopped.\n' >&2
        exit 1
    }
    terminate_dwl
)

# Keep package-owned installations package-owned; standalone paths stay unchanged.
if [ -L "$HOME/.local/bin/dwl" ] && [ "$(readlink -f "$HOME/.local/bin/dwl")" = /usr/bin/dwl ]; then
    update_packaged_dwl
    exit 0
fi

case "${ID:-} ${ID_LIKE:-}" in
    *arch*)
        src="$HOME/.local/src/dwl"
        patch="${XDG_CONFIG_HOME:-$HOME/.config}/dwl/patches/0001-neuroleptic.patch"
        protocol="${XDG_CONFIG_HOME:-$HOME/.config}/dwl/protocols/dwl-ipc-unstable-v2.xml"
        ref="d41ecb745cc94fbb48e93af01f5fd5d0b2488945"
        repo="https://codeberg.org/dwl/dwl.git"
        builddir=""

        cleanup() {
            if [ -n "$builddir" ] && [ -d "$builddir" ]; then
                git -C "$src" worktree remove --force "$builddir" >/dev/null 2>&1 || true
            fi
        }
        trap cleanup 0
        trap 'exit 130' 1 2 15

        [ -r "$patch" ] || {
            printf 'missing dwl patch: %s\n' "$patch" >&2
            exit 1
        }
        [ -r "$protocol" ] || {
            printf 'missing dwl protocol: %s\n' "$protocol" >&2
            exit 1
        }
        if [ ! -d "$src/.git" ]; then
            mkdir -p "$(dirname "$src")"
            git clone "$repo" "$src"
        fi
        if ! git -C "$src" cat-file -e "$ref^{commit}" 2>/dev/null; then
            git -C "$src" fetch origin "$ref"
        fi

        builddir=$(mktemp -d "${TMPDIR:-/tmp}/dwl-build.XXXXXX")
        git -C "$src" worktree add --detach "$builddir" "$ref"
        git -C "$builddir" apply --check "$patch"
        git -C "$builddir" apply "$patch"
        install -m 0644 "$protocol" "$builddir/protocols/dwl-ipc-unstable-v2.xml"
        install -m 0644 "$config" "$builddir/config.h"
        make -C "$builddir" clean
        make -C "$builddir" -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 1)" \
            PREFIX="$HOME/.local" CFLAGS="-O2 -pipe -march=native"
        cmp -s "$config" "$builddir/config.h" || { printf 'config.h changed during the build; retry before restarting.\n' >&2; exit 1; }
        make -C "$builddir" PREFIX="$HOME/.local" install

        cleanup
        trap - 0 1 2 15
        terminate_dwl
        ;;
    *gentoo*)
        src="$HOME/.local/src/dwl"
        cflags="-O3 -march=native -mtune=native -pipe -fno-math-errno \
-flto=thin -fomit-frame-pointer -fno-semantic-interposition \
-fno-stack-protector -fno-stack-clash-protection -fno-sanitize=all \
-fno-dwarf2-cfi-asm -ffp-contract=fast"
        ldflags="-fuse-ld=lld -flto=thin -rtlib=compiler-rt -Wl,-O3 \
-Wl,--lto-O3 -Wl,--as-needed -Wl,--gc-sections -Wl,--icf=all \
-Wl,--strip-all -Wl,-z,norelro -Wl,--build-id=none -Wl,--relax \
-Wl,-z,noseparate-code -Wl,-znow"

        [ -d "$src" ] || {
            printf 'missing dwl source tree: %s\n' "$src" >&2
            exit 1
        }
        command -v clang >/dev/null 2>&1 || {
            printf 'missing Gentoo dwl compiler: clang\n' >&2
            exit 1
        }
        command -v ld.lld >/dev/null 2>&1 || {
            printf 'missing Gentoo dwl linker: ld.lld\n' >&2
            exit 1
        }

        mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
        snapshot=$(mktemp "${XDG_CACHE_HOME:-$HOME/.cache}/dwl-config.XXXXXX")
        cp "$config" "$snapshot"
        trap 'rm -f -- "$snapshot"' 0
        trap 'exit 130' 1 2 15
        make -C "$src" clean
        make -C "$src" -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 1)" \
            CC=clang PREFIX="$HOME/.local" CFLAGS="$cflags" LDFLAGS="$ldflags"
        cmp -s "$config" "$snapshot" || { printf 'config.h changed during the build; retry before restarting.\n' >&2; exit 1; }
        make -C "$src" CC=clang PREFIX="$HOME/.local" \
            CFLAGS="$cflags" LDFLAGS="$ldflags" install
        terminate_dwl
        ;;
    *)
        printf 'unsupported distribution for dwl update: %s\n' \
            "${ID:-unknown}" >&2
        exit 1
        ;;
esac
