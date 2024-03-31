#!/bin/dash

killall "wf-recorder"

output_device="$(wpctl inspect "@DEFAULT_AUDIO_SINK@" | grep -o "alsa_output.*[[:alnum:]]")"
audiodevice="--audio=${output_device}.monitor"

videocodec="--codec=libx264"

audiocodec="--audio-codec=aac"
framerate="--framerate=60"

pixelformat="--pixel-format=yuv420p"

codecparameter1="--codec-param=crf=22"
codecparameter2="--codec-param=preset=ultrafast"
codecparameter3="--codec-param=tune=zerolatency"
codecparameter4="--codec-param=cpu-used=8"
filename="-f $(date "+%y%m%d_%H%M")"
extension=".mp4"

choice="$(printf "Start Recording\nExit\n" | bemenu -l "2")"

[ "${choice}" = "Start Recording" ] &&
	wf-recorder "${videocodec}" "${audiodevice}" "${audiocodec}" "${framerate}" --no-damage "${pixelformat}" "${codecparameter1}" "${codecparameter2}" "${codecparameter3}" "${codecparameter4}" "${filename}${extension}"
