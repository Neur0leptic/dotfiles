#!/bin/dash

langs="$(tesseract --list-langs 2>/dev/null |
         sed '1d;/^List/d;/osd/d;/enm/d')"

count=$(echo "$langs" | wc -l)

if [ "$count" -eq 1 ]; then
    lang="$langs"
else
    lang="$(echo "$langs" | while IFS= read -r l; do
                printf "%s\0icon\037accessories-camera\n" "$l"
            done | rofi -dmenu -i -show-icons -p "OCR")"
fi

geo="$(slurp)"
sleep "0.15"
grim -t "png" -l "0" -g "${geo}" - |
    tesseract stdin stdout -l "${lang}" | wl-copy
