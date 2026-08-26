#!/bin/bash

# ============================================
# uploader.sh - P2P File transfer tool using croc
# Features: Resume capability, encryption, no limits
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SU=""

detect_su() {
        if command -v doas &> /dev/null; then
                SU="doas"
        elif command -v sudo &> /dev/null; then
                SU="sudo"
        fi
}

error() {
        echo -e "${RED}[ERROR]${NC} $1" >&2
        exit 1
}

info() {
        echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
        echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check dependencies
check_dependencies() {
        detect_su

        [ -z "$SU" ] && warn "Neither doas nor sudo found. You may need root."

        # 1. Arch Linux
        if [ -f /etc/arch-release ]; then
                if ! command -v 7z &> /dev/null; then
                        warn "$SU pacman -S 7zip"
                fi
                if ! command -v croc &> /dev/null; then
                        warn "$SU pacman -S croc"
                fi

        # 2. Gentoo Linux
        elif [ -f /etc/gentoo-release ]; then
                if ! command -v 7z &> /dev/null; then
                        warn "$SU emerge app-arch/7zip"
                fi
                if ! command -v croc &> /dev/null; then
                        warn "$SU emerge net-misc/croc"
                fi

        # 3. Debian/Ubuntu/Zorin
        elif [ -f /etc/debian_version ]; then
                if ! command -v 7z &> /dev/null; then
                        warn "$SU apt install 7zip"
                fi
                if ! command -v croc &> /dev/null; then
                        warn "Install croc from https://github.com/schollz/croc"
                fi
        fi

        # Final check
        if ! command -v croc &> /dev/null; then
                error "croc could not be found. Please install it manually."
        fi
}

# Check if file is already compressed
is_compressible() {
        for f in "$@"; do
                [ -d "$f" ] && ! is_compressible "$f"/* && return 1
                case "${f##*.}" in
                        jpg | jpeg | jxl | mkv | mp4 | webm | mov | pdf | png | m4v | flv | avi | zip | rar | 7z | gz | bz2)
                                return 1
                                ;;
                esac
        done
        return 0
}

show_help() {
        echo "Usage:"
        echo "  $(basename "$0") file.txt           - Send a single file"
        echo "  $(basename "$0") -a file1 file2     - Send multiple files as archive"
        echo ""
        echo "Receiver runs:"
        echo "  croc <code>"
        exit 0
}

# ============================================
# MAIN
# ============================================

[ "$1" = "-h" ] || [ "$1" = "--help" ] && show_help
[ $# -eq 0 ] && error "No file specified! Use --help for help."

check_dependencies

if [ "$1" = "-a" ]; then
        shift
        [ $# -eq 0 ] && error "No files specified!"

        read -rp "Archive name: " ARCHIVE_BASENAME
        [ -z "$ARCHIVE_BASENAME" ] && ARCHIVE_BASENAME="archive_$(date +%Y%m%d_%H%M%S)"

        FINAL_ARCHIVE="${ARCHIVE_BASENAME}.7z"

        if is_compressible "$@"; then
                COMPRESSION_LEVEL="-mx=9"
        else
                COMPRESSION_LEVEL="-mx=0"
                warn "Already compressed files, storing only."
        fi

        info "Creating archive: $FINAL_ARCHIVE"
        7z a -t7z "$FINAL_ARCHIVE" $COMPRESSION_LEVEL "$@" || error "Failed to create archive!"

        echo ""
        info "Sending archive via croc..."
        croc send "$FINAL_ARCHIVE"

        rm -f "$FINAL_ARCHIVE"
        info "Temporary archive deleted."
else
        # Tek dosya modu
        [ $# -ne 1 ] && error "Use -a for multiple files."

        # Dosya yolu kontrolü
        FILE="$1"
        [ ! -e "$FILE" ] && error "Not found: $FILE"

        info "Sending file via croc..."
        croc send "$FILE"
fi
