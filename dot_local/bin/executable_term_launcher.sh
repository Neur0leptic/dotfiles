#!/usr/bin/env bash

FZF_COLORS="--color=bg+:#000000,bg:#000000,spinner:#03edf9,hl:#fede5d \
--color=fg:#f8f8f8,header:#af6df9,info:#72f1b8,pointer:#fe4450 \
--color=marker:#72f1b8,fg+:#ffffff,prompt:#03edf9,hl+:#fede5d \
--border=rounded --margin=0 --padding=1 --height=100% --layout=reverse"

entries=$(
  find /usr/share/applications /usr/local/share/applications "$HOME/.local/share/applications" \
    -name "*.desktop" ! -name "wine-extension*" 2>/dev/null | \
  xargs -d '\n' awk -F= '
    FNR == 1 && NR > 1 {
      if (n && e && !skip) print n "\t" e
      n = ""; e = ""; skip = 0
    }
    /^\[Desktop Entry\]/ { f = 1; skip = 0; next }
    /^\[/ { f = 0; next }
    f && /^(NoDisplay|Hidden)=true/ { skip = 1 }
    f && /^Name=/ { n = substr($0, index($0, "=") + 1) }
    f && /^Exec=/ { e = substr($0, index($0, "=") + 1); gsub(/%[UuFf]/, "", e); gsub(/"/, "", e) }
    END {
      if (n && e && !skip) print n "\t" e
    }
  '
)

[ -z "$entries" ] && exit 1

selected=$(echo "$entries" | fzf $FZF_COLORS --prompt="⚡ Run App > " --with-nth=1 --delimiter="\t")

[ -z "$selected" ] && exit 0

cmd=$(echo "$selected" | cut -f2- | sed 's/[[:space:]]*$//')

hyprctl dispatch exec "$cmd"
