#!/bin/dash

killall "wf-recorder" 2> /dev/null

output_device="$(wpctl inspect "@DEFAULT_AUDIO_SINK@" | grep -o "alsa_output.*[[:alnum:]]")"
audiodevice="--audio=${output_device}.monitor"

#videocodec="--codec=libx264"
videocodec="--codec=h264_nvenc"
audiocodec="--audio-codec=aac"
framerate="--framerate=60"
pixelformat="--pixel-format=yuv420p"

#codecparameter1="--codec-param=crf=22"
#codecparameter2="--codec-param=preset=ultrafast"
#codecparameter3="--codec-param=tune=zerolatency"
#codecparameter4="--codec-param=cpu-used=8"
codecparameter1="--codec-param=qp=22"
codecparameter2="--codec-param=rc=constqp"
codecparameter3="--codec-param=preset=p2"
codecparameter4="--codec-param=tune=ll"
outdir="${VIDEOS:-${HOME}/Videos}"
mkdir -p "${outdir}"
outfile="${outdir}/$(date "+%y%m%d_%H%M").mp4"

output_arg=""
outputs=""
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        outputs=$(hyprctl monitors 2> /dev/null | grep '^Monitor' | awk '{print $2}')
elif [ -n "${DWL_SESSION:-}" ]; then
        outputs=$(wlr-randr 2> /dev/null | grep '^[A-Z]' | awk '{print $1}')
fi
if [ -n "$outputs" ]; then
        count=$(echo "$outputs" | wc -l)
        if [ "$count" -gt 1 ]; then
                chosen=$(echo "$outputs" | rofi -dmenu -p "Select Output" -lines "$count")
                [ -z "$chosen" ] && exit 0
                output_arg="--output=${chosen}"
        fi
fi

choice="$(printf "Start Recording\nExit\n" | rofi -dmenu -p "Screen Recorder" -lines 2)"
[ "${choice}" != "Start Recording" ] && exit 0

wf-recorder -f "${outfile}" \
        ${output_arg:+"$output_arg"} \
        "${videocodec}" "${audiodevice}" "${audiocodec}" \
        "${framerate}" --no-damage "${pixelformat}" \
        "${codecparameter1}" "${codecparameter2}" \
        "${codecparameter3}" "${codecparameter4}"
