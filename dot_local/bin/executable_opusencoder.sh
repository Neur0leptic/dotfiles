#!/bin/sh

ffmpeg -i "${1}" \
       -c:a libopus \
       -b:a 384k \
       -compression_level 10 \
       -mapping_family 255 \
       -vbr on \
       "opus_${1%.*}.opus"
