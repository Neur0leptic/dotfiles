#!/bin/sh

ffmpeg -i "${1}" \
       -acodec libopus \
       -b:a 128k \
       -vbr on \
       -compression_level 10 \
       -application audio \
       -frame_duration 20 \
       -mapping_family 0 \
       -packet_loss 0 \
       "opus_${1%.*}.opus"

Test1
Test2
Test3
Test4
