#!/bin/sh

if pgrep -x unimatrix > /dev/null; then
        exit 0
fi

kitty --class fullscreen -e unimatrix &
disown
