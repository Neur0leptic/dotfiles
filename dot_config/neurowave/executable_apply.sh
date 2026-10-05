#!/usr/bin/env bash
set -euo pipefail

NEURO_DIR="${HOME}/.config/neurowave"
TEMPLATES_DIR="${NEURO_DIR}/templates"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"

source "${NEURO_DIR}/palette.sh"

VARS='$XDG_DATA_HOME $BASE00 $BASE01 $BASE02 $BASE03 $BASE04 $BASE05 $BASE06 $BASE07 $BASE08 $BASE09 $BASE0A $BASE0B $BASE0C $BASE0D $BASE0E $BASE0F $BASE10 $BASE11 $BASE12 $BASE13 $BASE14 $BASE15 $BASE16 $BASE17 $BASE00_R $BASE00_G $BASE00_B $BASE05_R $BASE05_G $BASE05_B $BASE07_R $BASE07_G $BASE07_B $BASE08_R $BASE08_G $BASE08_B $BASE09_R $BASE09_G $BASE09_B $BASE0A_R $BASE0A_G $BASE0A_B $BASE0B_R $BASE0B_G $BASE0B_B $BASE0C_R $BASE0C_G $BASE0C_B $BASE0D_R $BASE0D_G $BASE0D_B $BASE0E_R $BASE0E_G $BASE0E_B $BASE11_R $BASE11_G $BASE11_B $BASE12_R $BASE12_G $BASE12_B $BASE14_R $BASE14_G $BASE14_B $BASE15_R $BASE15_G $BASE15_B $BASE16_R $BASE16_G $BASE16_B $P10K_GREEN $P10K_RED $P10K_YELLOW $P10K_BLUE $P10K_PURPLE $P10K_CYAN $P10K_ORANGE $P10K_GREY $P10K_PINK $P10K_TEAL $P10K_INDIGO'

apply() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "${dst}")"
  envsubst "$VARS" < "${src}" > "${dst}"
  echo "  -> ${dst}"
}

echo "=== Neurowave Theme Apply ==="
echo ""

# foot
apply "${TEMPLATES_DIR}/foot.ini.template" \
  "${HOME}/.config/foot/foot.ini"

# kitty
apply "${TEMPLATES_DIR}/kitty.conf.template" \
  "${HOME}/.config/kitty/kitty.conf"

# waybar
apply "${TEMPLATES_DIR}/waybar.css.template" \
  "${HOME}/.config/waybar/style.css"

# rofi
apply "${TEMPLATES_DIR}/rofi.rasi.template" \
  "${HOME}/.config/rofi/theme.rasi"

# mako
apply "${TEMPLATES_DIR}/mako.conf.template" \
  "${HOME}/.config/mako/config"

# hyprland appearance
apply "${TEMPLATES_DIR}/hypr_appearance.lua.template" \
  "${HOME}/.config/hypr/appearance.lua"

# swaylock
apply "${TEMPLATES_DIR}/swaylock.conf.template" \
  "${HOME}/.config/swaylock/config"

# yazi
apply "${TEMPLATES_DIR}/yazi_theme.toml.template" \
  "${HOME}/.config/yazi/theme.toml"

# nvim
apply "${TEMPLATES_DIR}/nvim_colorscheme.lua.template" \
  "${HOME}/.config/nvim/lua/plugins/colorscheme.lua"

# Kvantum
apply "${TEMPLATES_DIR}/Neurowave.kvconfig.template" \
  "${HOME}/.local/share/Kvantum/Neurowave/Neurowave.kvconfig"

# Anki
apply "${TEMPLATES_DIR}/anki.qss.template" \
  "${HOME}/.local/share/Anki2/_anki.qss"

apply "${TEMPLATES_DIR}/anki_webview.py.template" \
  "${HOME}/.local/share/Anki2/addons21/dark_cards/__init__.py"

# LibreWolf portable inputs; the installer links the active profile to these files.
apply "${TEMPLATES_DIR}/librewolf_userChrome.css.template" \
  "${HOME}/.config/librewolf/chrome/userChrome.css"
apply "${TEMPLATES_DIR}/librewolf_userContent.css.template" \
  "${HOME}/.config/librewolf/chrome/userContent.css"

echo ""
echo "=== Done ==="
