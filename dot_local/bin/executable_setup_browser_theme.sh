#!/usr/bin/env bash
# Attach managed theme files once; never run Arkenfox or synchronize profile data.
set -euo pipefail
umask 077

mode="${1:---apply}"
case "$mode" in --apply|--check|--librewolf-profile) ;; *) printf 'Unknown option: %s\n' "$mode" >&2; exit 2 ;; esac
[[ $# -le 1 ]] || exit 2
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
uid="$(id -u)"
temporary=""
trap 'if [[ -n "$temporary" ]]; then rm -f -- "$temporary" "$temporary.merged"; fi' EXIT

fail() { printf 'Browser theme: %s\n' "$*" >&2; exit 1; }

safe_directory() {
    local path="$1" permissions
    [[ "$path" == "$HOME" || "$path" == "$HOME/"* ]] || return 1
    [[ -d "$path" && ! -L "$path" && "$(readlink -m "$path")" == "$path" && "$(stat -c %u "$path")" == "$uid" ]] || return 1
    permissions="$(stat -c %a "$path")"
    (( (8#$permissions & 8#022) == 0 ))
}

ensure_directory() {
    local path="$1"
    [[ "$path" == "$HOME/"* && "$(readlink -m "$path")" == "$path" ]] || fail "unsafe directory: $path"
    if [[ -e "$path" || -L "$path" ]]; then
        safe_directory "$path" || fail "unsafe directory: $path"
    else
        if [[ "$(dirname "$path")" != "$HOME" ]]; then ensure_directory "$(dirname "$path")"; fi
        mkdir -- "$path"
    fi
}

safe_file() {
    local path="$1" permissions
    safe_directory "$(dirname "$path")" || return 1
    [[ -f "$path" && ! -L "$path" && "$(stat -c %u "$path")" == "$uid" && "$(stat -c %h "$path")" == 1 ]] || return 1
    permissions="$(stat -c %a "$path")"
    (( (8#$permissions & 8#022) == 0 ))
}

librewolf_profile() {
    local root selection relative path
    for root in "$HOME/.librewolf" "$config_home/librewolf/librewolf" "$config_home/librewolf"; do
        [[ -e "$root/profiles.ini" || -L "$root/profiles.ini" ]] || continue
        safe_file "$root/profiles.ini" || fail "unsafe LibreWolf profile registry"
        selection="$(awk '
            function save() {
                if (section ~ /^Install/ && values["Default"] != "") {
                    installs[values["Default"]] = 1
                } else if (section ~ /^Profile[0-9]+$/ && values["Path"] != "") {
                    paths[++count] = values["Path"]
                    relative[count] = values["IsRelative"]
                    defaults[count] = values["Default"]
                }
                delete values
            }
            { sub(/\r$/, "") }
            /^\[/ { save(); section = substr($0, 2, length($0) - 2); next }
            /^[^;#][^=]*=/ {
                separator = index($0, "=")
                values[substr($0, 1, separator - 1)] = substr($0, separator + 1)
            }
            END {
                save()
                for (path in installs) { selected = path; install_count++ }
                if (install_count > 1) exit 1
                if (install_count == 1) {
                    for (i = 1; i <= count; i++) {
                        if (paths[i] == selected) { print relative[i] "\t" selected; exit }
                    }
                    print (substr(selected, 1, 1) == "/" ? "0" : "1") "\t" selected
                    exit
                }
                for (i = 1; i <= count; i++) {
                    if (defaults[i] == "1") { selected_index = i; default_count++ }
                }
                if (default_count == 0 && count == 1) selected_index = 1
                if (default_count > 1 || selected_index == 0) exit 1
                print relative[selected_index] "\t" paths[selected_index]
            }
        ' "$root/profiles.ini")" || fail "LibreWolf has no unambiguous default profile"
        IFS=$'\t' read -r relative path <<<"$selection"
        [[ -n "$path" && ! "$path" =~ [[:cntrl:]] ]] || fail "invalid LibreWolf profile path"
        case "$relative" in
            1) [[ "$path" != /* ]] || fail "invalid relative profile"; path="$(readlink -m "$root/$path")" ;;
            0) [[ "$path" == /* ]] || fail "invalid absolute profile" ;;
            *) fail "invalid LibreWolf IsRelative value" ;;
        esac
        safe_directory "$path" || fail "unsafe or missing LibreWolf profile: $path"
        printf '%s\n' "$path"
        return 0
    done
    fail "LibreWolf profile is missing; complete its setup first"
}

attach_css() {
    local source="$1" destination="$2"
    safe_file "$source" || fail "unsafe managed CSS: $source"
    if [[ "$mode" == --check ]]; then
        safe_directory "$(dirname "$destination")" || return 1
    else
        ensure_directory "$(dirname "$destination")"
    fi
    if [[ -L "$destination" && "$(readlink "$destination")" == "$source" ]]; then return 0; fi
    [[ "$mode" != --check ]] || return 1
    if [[ -e "$destination" || -L "$destination" ]]; then
        safe_file "$destination" && cmp -s "$source" "$destination" || \
            fail "different existing CSS preserved; review $destination before attaching the managed theme"
    fi
    temporary="$(mktemp "$(dirname "$destination")/.theme-link.XXXXXX")"
    rm -f -- "$temporary"
    ln -s -- "$source" "$temporary"
    mv -Tf -- "$temporary" "$destination"
    temporary=""
}

helium_theme() {
    local policy="$config_home/helium-browser-theme.json" root profile=Default preferences before permissions=600
    root="$config_home/net.imput.helium"
    safe_file "$policy" || fail "unsafe or missing Helium appearance policy"
    jq -e '.extensions.theme.id == "" and .extensions.theme.system_theme == 1
        and (.browser.theme.color_scheme2 | type == "number" and . >= 0 and . <= 2)' "$policy" >/dev/null || fail "invalid Helium appearance policy"
    if [[ -e "$root/Local State" || -L "$root/Local State" ]]; then
        safe_file "$root/Local State" || fail "unsafe Helium profile registry"
        profile="$(jq -er '.profile.last_used // "Default" | select(type == "string" and length > 0)' "$root/Local State")" || fail "invalid Helium active profile"
    fi
    [[ "$profile" != */* && "$profile" != . && "$profile" != .. && ! "$profile" =~ [[:cntrl:]] ]] || fail "invalid Helium profile name"
    preferences="$root/$profile/Preferences"
    if [[ -e "$preferences" || -L "$preferences" ]]; then
        safe_file "$preferences" || fail "unsafe Helium Preferences file"
        if jq -e --slurpfile policy "$policy" '
            .extensions.theme.id == $policy[0].extensions.theme.id
            and .extensions.theme.system_theme == $policy[0].extensions.theme.system_theme
            and .browser.theme.color_scheme2 == $policy[0].browser.theme.color_scheme2
        ' "$preferences" >/dev/null; then return 0; fi
        before="$(sha256sum "$preferences")"
        permissions="$(stat -c %a "$preferences")"
    else
        before=missing
    fi
    [[ "$mode" != --check ]] || return 1
    if pgrep -u "$uid" -x 'helium|helium-browser' >/dev/null; then
        fail "close Helium before changing its appearance; its profile has not been modified"
    fi
    ensure_directory "$root/$profile"
    temporary="$(mktemp "$root/$profile/.Preferences-theme.XXXXXX")"
    if [[ "$before" == missing ]]; then printf '{}\n' >"$temporary";
    else cat -- "$preferences" >"$temporary"; fi
    jq -e 'type == "object"' "$temporary" >/dev/null || fail "Helium Preferences is not an object"
    # Only these three appearance fields are managed; retain all other profile data.
    jq --slurpfile policy "$policy" '
        .extensions.theme.id = $policy[0].extensions.theme.id |
        .extensions.theme.system_theme = $policy[0].extensions.theme.system_theme |
        .browser.theme.color_scheme2 = $policy[0].browser.theme.color_scheme2
    ' "$temporary" >"$temporary.merged"
    mv -T -- "$temporary.merged" "$temporary"
    chmod "$permissions" "$temporary"
    if [[ "$before" == missing ]]; then
        [[ ! -e "$preferences" && ! -L "$preferences" ]] || fail "Helium profile changed during theme setup"
    else
        safe_file "$preferences" && [[ "$(sha256sum "$preferences")" == "$before" ]] || fail "Helium profile changed during theme setup"
    fi
    ! pgrep -u "$uid" -x 'helium|helium-browser' >/dev/null || fail "Helium started during theme setup"
    mv -T -- "$temporary" "$preferences"
    temporary=""
}

safe_directory "$HOME" || fail "unsafe home directory"
profile="$(librewolf_profile)"
if [[ "$mode" == --librewolf-profile ]]; then printf '%s\n' "$profile"; exit 0; fi
safe_file "$HOME/.librewolf/librewolf.overrides.cfg" || fail "native LibreWolf UI overrides are missing"
for css in userChrome.css userContent.css; do
    attach_css "$config_home/librewolf/chrome/$css" "$profile/chrome/$css"
done
helium_theme
[[ "$mode" == --check ]] || printf '%s\n' 'Browser themes configured; restart the browsers to load the appearance settings.'
