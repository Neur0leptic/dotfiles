[ -z "${1}" ] && printf "%s\n" "Specify a video file to re-encode." && exit "1"

av1an -i "${1}" \
        -o "av1_opus_${1%.*}.mkv" \
	--encoder "svt-av1" \
	--split-method "av-scenechange" \
        --workers "1" \
        --chunk-method "lsmash" \
	--sc-method "standard" \
	--resume \
        --pix-format "yuv420p10le" \
        --video-params "--preset 4 \
	                --crf 15 \
			--tune 2 \
			--enable-qm 1 \
			--qm-min 0 \
			--qm-max 10 \
			--input-depth 10 \
			--enable-overlays 1 \
			--scd 1 \
			--keyint -1 \
			--lp 16 \
			--pin 1 \
			--enable-dlf 1 \
			--fast-decode 0 \
			--irefresh-type 2 \
			--enable-restoration 1 \
			--scm 2 \
			--enable-tf 1 \
			--aq-mode 2 \
			--enable-cdef 1 \
			--enable-tpl-la 1 \
			--color-range 0 \
			--film-grain 0 \
			--film-grain-denoise 0 \
			--color-primaries 9 \
			--transfer-characteristics 16 \
			--matrix-coefficients 9 \
			--chroma-sample-position 2 \
			--mastering-display G(0.08456,0.84405)B(0.17562,0.07496)R(0.68446,0.31995)WP(0.32168,0.33767)L(1000,0.005) \
			--content-light 1000,63"


## TESTING ##
# ssimulacra2_rs video "${1}" "av1_opus_${1%.*}.mkv"

## SCALING ##
# -f "-vf scale=1280:720" \

## Color Settings ##
# --color-primaries 9 \
# --transfer-characteristics 16 \
# --matrix-coefficients 9 \
# --chroma-sample-position 2 \
# --mastering-display G(0.08456,0.84405)B(0.17562,0.07496)R(0.68446,0.31995)WP(0.32168,0.33767)L(1000,0.005) \
# --content-light 1000,63"
