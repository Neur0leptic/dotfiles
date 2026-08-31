#!/bin/sh

set -eu

terminate_dwl() {
    if pgrep -x -u "$(id -u)" dwl >/dev/null 2>&1; then
        pkill -TERM -x -u "$(id -u)" dwl
    fi
}

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
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
        trap cleanup 0 1 2 15

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
        make -C "$builddir" clean
        make -C "$builddir" -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 1)" \
            PREFIX="$HOME/.local" CFLAGS="-O2 -pipe -march=native"
        make -C "$builddir" PREFIX="$HOME/.local" install

        cleanup
        trap - 0 1 2 15
        terminate_dwl
        ;;
    *)
        cd "$HOME/.local/src/dwl"
        CC=clang CFLAGS="-fno-pic -fno-pie -Ofast -flto=full -pipe -march=native -mtune=native -fomit-frame-pointer -funroll-loops" LDFLAGS="-fuse-ld=lld -rtlib=compiler-rt -unwindlib=libunwind -Wl,-O3 -Wl,--as-needed -Wl,--gc-sections -Wl,--icf=all" make
        doas make install
        terminate_dwl
        ;;
esac
