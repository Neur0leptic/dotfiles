#!/bin/sh
geometry=$(slurp) && sleep 0.3 && grim -g "$geometry" - | tesseract stdin stdout 2>/dev/null | wl-copy
