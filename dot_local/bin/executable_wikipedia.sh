#!/bin/sh

query="$(timeout 2 wl-paste --primary 2>/dev/null || true)"
query="$(printf '%s' "${query}" | tr -d '[:cntrl:]' | xargs)"

if [ -z "${query}" ]; then
    footclient -e wiki-tui
else
    footclient -e wiki-tui "${query}"
fi
