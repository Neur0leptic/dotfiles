#!/bin/sh

output="${5:-${1%.mkv}_combined.mkv}"

case "${1}" in *.mkv) ;; *)
        echo "\"${1}\" must be .mkv"
        exit 1
        ;;
esac
case "${2}" in *.opus) ;; *)
        echo "\"${2}\" must be .opus"
        exit 1
        ;;
esac
case "${3}" in *.srt) ;; *)
        echo "\"${3}\" must be .srt"
        exit 1
        ;;
esac
case "${4}" in *.srt) ;; *)
        echo "\"${4}\" must be .srt"
        exit 1
        ;;
esac

ffmpeg -i "${1}" -i "${2}" \
        -sub_charenc "UTF-8" -i "${3}" \
        -sub_charenc "UTF-8" -i "${4}" \
        -map "0:v" -map "1:a" -map "2" -map "3" \
        -c:v "copy" -c:a "copy" -c:s "srt" \
        -metadata:s:s:0 language=eng -metadata:s:s:0 title="English" \
        -metadata:s:s:1 language=tur -metadata:s:s:1 title="Turkish" \
        "${output}"
