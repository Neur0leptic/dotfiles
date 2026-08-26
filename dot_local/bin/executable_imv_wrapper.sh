#!/usr/bin/env zsh
setopt nullglob
f=(*.{jpg,jxl,png,webp,svg})
i="${f[(I)$1:t]}"
imv -f "${f[@]:$((i-1))}" "${f[@]:0:$((i-1))}"
