#!/bin/sh

set -eu

# ===== Constants =====
readonly SCRIPT_NAME="WebApp Installer"
readonly DESKTOP_DIR="${HOME}/.local/share/applications"
readonly ICON_DIR="${DESKTOP_DIR}/icons"
readonly ICONS_BASE="${XDG_DATA_HOME:-${HOME}/.local/share}/icons/candy-icons"
readonly XDG_BIN_HOME="${XDG_BIN_HOME:-${HOME}/.local/bin}"
# ===== Setup =====
mkdir -p "$DESKTOP_DIR" "$ICON_DIR"

# Verify rofi exists
command -v rofi > /dev/null 2>&1 || {
        printf 'Error: rofi is not installed\n' >&2
        exit 1
}

# ===== Core Functions =====

# Display error and exit
die() {
        notify-send -u critical "$SCRIPT_NAME" "Error: $1"
        exit 1
}

# Rofi input prompt
prompt() {
        _result=$(rofi -dmenu -i -no-fixed-num-lines -p "$1") || return 1
        [ -n "$_result" ] || return 1
        printf '%s' "$_result"
}

# Rofi selection menu
menu() {
        _label=$1
        shift
        printf '%s\n' "$@" | rofi -dmenu -i -no-fixed-num-lines -p "$_label"
}

# Icon selector with visual preview (includes PNG and searches ICON_DIR)
select_icon() {
        [ -d "$ICONS_BASE" ] || die "Icon directory not found: $ICONS_BASE"

        # Combine icons from both directories, include PNG and SVG files
        {
                find "$ICONS_BASE" -type f \( -name "*.svg" -o -name "*.png" \) 2> /dev/null
                [ -d "$ICON_DIR" ] && find "$ICON_DIR" -type f \( -name "*.svg" -o -name "*.png" \) 2> /dev/null
        } |
                sort -u |
                while IFS= read -r _icon_path; do
                        printf '%s\0icon\x1f%s\n' "${_icon_path##*/}" "$_icon_path"
                done |
                rofi -dmenu -i -no-fixed-num-lines -show-icons -p "Select Icon" -format 's'
}

# Transform string to valid filename
sanitize() {
        printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd '[:alnum:]-'
}

# Locate and install icon file
setup_icon() {
        _icon_name=$1
        _app_id=$2

        [ -z "$_icon_name" ] && {
                printf '%s/%s.png' "$ICON_DIR" "$_app_id"
                return 1
        }

        # Search in both ICONS_BASE and ICON_DIR
        _icon_src=$(find "$ICONS_BASE" "$ICON_DIR" -type f -name "$_icon_name" -print -quit 2> /dev/null)

        [ -n "$_icon_src" ] && {
                _icon_ext=${_icon_name##*.}
                _icon_dest="${ICON_DIR}/${_app_id}.${_icon_ext}"

                # Prevent copying file to itself (if icon is already in ICON_DIR)
                [ "$_icon_src" = "$_icon_dest" ] && {
                        printf '%s' "$_icon_dest"
                        return 0
                }

                cp "$_icon_src" "$_icon_dest" 2> /dev/null && {
                        printf '%s' "$_icon_dest"
                        return 0
                }
        }

        printf '%s/%s.png' "$ICON_DIR" "$_app_id"
        return 1
}

# Send notification via dunst
notify() {
        _title=$1
        _body=$2
        _urgency=${3:-normal}

        notify-send -a "$SCRIPT_NAME" -u "$_urgency" "$_title" "$_body"
}

# Validate URL format
validate_url() {
        _url=$1

        case "$_url" in
                http://* | https://*)
                        return 0
                        ;;
                *)
                        return 1
                        ;;
        esac
}

# ===== Main Workflow =====

# Dynamically get installed browsers
get_installed_browsers() {
        {
                for f in /usr/share/applications/*.desktop /usr/local/share/applications/*.desktop "$HOME/.local/share/applications"/*.desktop; do
                        [ -f "$f" ] || continue
                        if grep -q "Categories=.*WebBrowser" "$f"; then
                                exec_line=$(grep "^Exec=" "$f" | head -n 1 | cut -d= -f2-)
                                exec_cmd=$(echo "$exec_line" | awk '{print $1}')
                                exec_cmd=$(basename "$exec_cmd" | tr -d '"'\''')
                                case "$exec_cmd" in
                                        *_launch_webapp.sh|*launch-webapp*|*webapp*) continue ;;
                                esac
                                if command -v "$exec_cmd" >/dev/null 2>&1; then
                                        echo "$exec_cmd"
                                fi
                        fi
                done
                for cmd in helium-browser thorium-browser librewolf firefox chromium google-chrome-stable brave; do
                        if command -v "$cmd" >/dev/null 2>&1; then
                                echo "$cmd"
                        fi
                done
        } | sort -u
}

installed_browsers=$(get_installed_browsers)
[ -n "$installed_browsers" ] || die "No web browsers found on the system."

# Browser selection
browser=$(menu "Select Browser" $installed_browsers) || die "Browser selection cancelled"
[ -n "$browser" ] || die "No browser selected"

launcher="${browser}_launch_webapp.sh"
launcher_path="${XDG_BIN_HOME}/${launcher}"

if [ ! -f "$launcher_path" ]; then
        if echo "$browser" | grep -qE "librewolf|firefox|mullvad|waterfox|iceweasel"; then
                template_path="${XDG_BIN_HOME}/librewolf_launch_webapp.sh"
                [ -f "$template_path" ] || die "Template for Firefox-like browsers not found at $template_path"
                sed "s/librewolf/${browser}/g" "$template_path" > "$launcher_path"
        else
                template_path="${XDG_BIN_HOME}/helium_launch_webapp.sh"
                if [ ! -f "$template_path" ]; then
                        template_path="${XDG_BIN_HOME}/thorium_launch_webapp.sh"
                fi
                [ -f "$template_path" ] || die "Template for Chromium-like browsers not found"
                sed -e "s/helium-browser/${browser}/g" \
                    -e "s/thorium-browser/${browser}/g" \
                    -e "s/helium-webapps/${browser}-webapps/g" \
                    -e "s/thorium-webapps/${browser}-webapps/g" \
                    "$template_path" > "$launcher_path"
        fi
        chmod +x "$launcher_path"
        notify "Launcher Created" "Created new webapp launcher for $browser: $launcher" "normal"
fi

# Application name
app_name=$(prompt "App Name") || die "App name input cancelled"
[ -n "$app_name" ] || die "App name cannot be empty"

# Application URL with validation
while true; do
        app_url=$(prompt "App URL (https://...)") || die "URL input cancelled"
        [ -n "$app_url" ] || die "URL cannot be empty"

        validate_url "$app_url" && break

        notify "Invalid URL" "Please enter a valid URL starting with http:// or https://" "critical"
done

# Icon selection
icon_file=$(select_icon) || die "Icon selection cancelled"

# Generate identifiers
app_id=$(sanitize "$app_name")
icon_path=$(setup_icon "$icon_file" "$app_id")

# Desktop entry creation
desktop_file="${DESKTOP_DIR}/${app_id}.desktop"

# Check if already exists
[ -f "$desktop_file" ] && {
        notify "File Exists" "WebApp '$app_name' will be overwritten" "normal"
}

# Write desktop file
cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$app_name
Comment=$app_name Web Application
Exec=$XDG_BIN_HOME/$launcher "$app_url" "$app_id"
Icon=$icon_path
Terminal=false
StartupNotify=true
Categories=Network;WebBrowser;
StartupWMClass=WebApp-$app_id
Keywords=webapp;browser;
EOF

chmod +x "$desktop_file" || die "Failed to set execute permission"

# Update desktop database
command -v update-desktop-database > /dev/null 2>&1 && {
        update-desktop-database "$DESKTOP_DIR" 2> /dev/null || true
}

# Success notification
notify "Installation Complete" "✓ WebApp '$app_name' installed successfully!\n\nLaunch: gtk-launch $app_id.desktop" "normal"

exit 0
