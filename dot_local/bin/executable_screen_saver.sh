#!/bin/sh

if pgrep -x unimatrix > /dev/null; then
        exit 0
fi

footclient -a fullscreen unimatrix &
disown
