#!/bin/sh

# net_scan.sh - Scan local network and identify known devices
#
# Usage:
#   net_scan.sh              Scan network and list all devices
#   net_scan.sh --name MAC "Name"  Save a device name to cache
#   net_scan.sh --list       Show cached device names
#   net_scan.sh --help       Show this help

set -u

CONFIG_DIR="${HOME}/.config/network_scan"
CACHE_FILE="${CONFIG_DIR}/known_macs"

# ---------- Help ----------
show_help() {
    sed -n '2,/^$/s/^#\s\?//p' "$0"
    exit 0
}

# ---------- Package management ----------
detect_pm() {
    if command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v emerge >/dev/null 2>&1; then
        echo "emerge"
    else
        echo "unknown"
    fi
}

ensure_arp_scan() {
    if command -v arp-scan >/dev/null 2>&1; then
        return 0
    fi

    pm=$(detect_pm)
    echo "[*] arp-scan not found."

    case "$pm" in
        pacman)
            printf "Install arp-scan? [Y/n]: "
            read -r ans
            case "${ans:-Y}" in y|Y|"")
                sudo pacman -S --noconfirm arp-scan || {
                    echo "[!] Failed to install arp-scan."
                    exit 1
                }
                ;;
            *)
                exit 1
                ;;
            esac
            ;;
        emerge)
            printf "Install arp-scan? [Y/n]: "
            read -r ans
            case "${ans:-Y}" in y|Y|"")
                sudo emerge -1 arp-scan || {
                    echo "[!] Failed to install arp-scan."
                    exit 1
                }
                ;;
            *)
                exit 1
                ;;
            esac
            ;;
        *)
            echo "[!] Unknown package manager. Install arp-scan manually."
            exit 1
            ;;
    esac
}

# ---------- Cache ----------
ensure_config() {
    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$CACHE_FILE" ]; then
        touch "$CACHE_FILE"
    fi
}

cache_name() {
    mac=$(echo "$1" | tr 'a-f' 'A-F' | sed 's/[ :.-]//g')
    name="$2"

    tmp=$(mktemp)
    # Remove old entry regardless of colon format
    mac_colon=$(echo "$mac" | sed 's/\(..\)/\1:/g;s/:$//')
    grep -iv "$mac" "$CACHE_FILE" | grep -iv "$mac_colon" > "$tmp" 2>/dev/null
    printf "%s\t%s\n" "$mac" "$name" >> "$tmp"
    mv "$tmp" "$CACHE_FILE"
    echo "[+] $mac -> $name"
}

cache_lookup() {
    mac=$(echo "$1" | tr 'a-f' 'A-F' | sed 's/[ :.-]//g')
    grep -iF "$mac" "$CACHE_FILE" 2>/dev/null | awk -F'\t' '{print $2}' | head -1
}

list_cache() {
    if [ ! -f "$CACHE_FILE" ] || [ ! -s "$CACHE_FILE" ]; then
        echo "[-] No cached names yet."
        return
    fi

    count=0
    echo "Known devices (${CACHE_FILE}):"
    echo "----------------------------------------"
    while IFS='	' read -r mac name; do
        [ -z "$mac" ] && continue
        case "$mac" in \#*) continue ;; esac
        printf "  %-20s %s\n" "$name" "$mac"
        count=$((count + 1))
    done < "$CACHE_FILE"
    echo "----------------------------------------"
    echo "Total: $count"
}

# ---------- Hostname resolution ----------
resolve_hostname() {
    ip="$1"
    result=""

    # Method 1: reverse DNS (host command)
    if command -v host >/dev/null 2>&1; then
        result=$(host "$ip" 2>/dev/null | head -1 | awk '{print $NF}' | sed 's/\.$//')
        case "$result" in
            *"NXDOMAIN"*|*"not found"*|*"SERVFAIL"*|*"REFUSED"*) result="" ;;
        esac
    fi

    # Method 2: mDNS / Bonjour (avahi)
    if [ -z "$result" ] && command -v avahi-resolve-address >/dev/null 2>&1; then
        result=$(avahi-resolve-address "$ip" 2>/dev/null | awk '{print $2}')
    fi

    echo "$result"
}

# ---------- Scan ----------
scan_network() {
    iface=$(ip route show default | awk '{print $5}' | head -1)
    if [ -z "$iface" ]; then
        echo "[!] Could not detect default network interface."
        exit 1
    fi

    subnet=$(ip -o -4 addr show "$iface" | awk '{print $4}' | head -1)
    if [ -z "$subnet" ]; then
        echo "[!] Could not detect subnet."
        exit 1
    fi

    echo "NETWORK SCAN - $subnet"
    echo "----------------------------------------"

    tmpfile=$(mktemp)
    sudo arp-scan --localnet --format='${ip}\t${mac}\t${vendor}' > "$tmpfile" 2>/dev/null
    scan_rc=$?

    if [ $scan_rc -ne 0 ]; then
        echo "[!] arp-scan failed."
        IFS=''
        rm -f "$tmpfile"
        exit 1
    fi

    known_count=0
    unknown_count=0

    while IFS="$(printf '\t')" read -r ip mac vendor; do
        # Skip non-data lines (headers, footers)
        case "$ip" in
            [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*) ;;
            *) continue ;;
        esac

        mac_upper=$(echo "$mac" | tr 'a-f' 'A-F')
        name=$(cache_lookup "$mac_upper")

        if [ -n "$name" ]; then
            known_count=$((known_count + 1))
            printf "  + %-15s %-20s %-17s %s\n" "$ip" "$name" "$mac" "$vendor"
        else
            hname=$(resolve_hostname "$ip")
            unknown_count=$((unknown_count + 1))
            if [ -n "$hname" ]; then
                printf "  ? %-15s %-20s %-17s (%s)\n" "$ip" "Unknown ($hname)" "$mac" "$vendor"
            else
                printf "  ? %-15s %-20s %-17s %s\n" "$ip" "Unknown" "$mac" "$vendor"
            fi
        fi
    done < "$tmpfile"

    rm -f "$tmpfile"

    total=$((known_count + unknown_count))
    echo "----------------------------------------"
    echo "  Total: $total | Known: $known_count | Unknown: $unknown_count"
}

# ---------- Main ----------
case "${1:-}" in
    --help|-h)
        show_help
        ;;
    --list)
        list_cache
        exit 0
        ;;
    --name)
        if [ $# -lt 3 ]; then
            echo "[!] Usage: net_scan.sh --name MAC \"Device Name\""
            exit 1
        fi
        ensure_config
        cache_name "$2" "$3"
        exit 0
        ;;
    "")
        ensure_arp_scan
        ensure_config
        scan_network
        ;;
    *)
        echo "[!] Unknown option: $1"
        echo "    Use --help for usage."
        exit 1
        ;;
esac
