{{- /* This machine's DWL sections, from its saved installer answers. */ -}}
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{- $renderer := $settings.renderer -}}
{{- if eq $renderer "auto" }}{{ $renderer = "" }}{{ end -}}
{{- $rules := "" -}}
{{- $masks := dict "1" 1 "2" 2 "3" 4 "4" 8 "5" 16 "6" 32 "7" 64 "8" 128 "9" 256 "10" 512 -}}
{{- range $output := $settings.outputs -}}
{{- $width := 0 }}{{ $height := 0 }}{{ $refresh := 0 -}}
{{- if ne $output.mode "preferred" -}}
{{- $mode := splitList "@" $output.mode -}}
{{- $dimensions := splitList "x" (index $mode 0) -}}
{{- $width = index $dimensions 0 | atoi }}{{ $height = index $dimensions 1 | atoi -}}
{{- if gt (len $mode) 1 }}{{ $refresh = round (mulf (index $mode 1 | float64) 1000) 0 | int }}{{ end -}}
{{- end -}}
{{- $x := -1 }}{{ $y := -1 -}}
{{- if ne $output.position "auto" -}}
{{- $position := splitList "," $output.position -}}
{{- $x = index $position 0 | atoi }}{{ $y = index $position 1 | atoi -}}
{{- end -}}
{{- $mask := 0 -}}
{{- range $tag := $output.tags }}{{ $mask = add $mask (get $masks ($tag | toString)) }}{{ end -}}
{{- $image := "NULL" }}{{ $format := "DRM_FORMAT_XRGB8888" -}}
{{- if eq $output.color "wide" }}{{ $image = "&bt2020_sdr" }}{{ $format = "DRM_FORMAT_XBGR2101010" }}{{ end -}}
{{- $disabled := 0 }}{{ if not $output.enabled }}{{ $disabled = 1 }}{{ end -}}
{{- $rules = printf "%s\t{\n\t\t.name = %s, .mfact = 0.55f, .nmaster = 1, .scale = %.6ff,\n\t\t.lt = &layouts[0], .rr = WL_OUTPUT_TRANSFORM_NORMAL, .x = %d, .y = %d,\n\t\t.width = %d, .height = %d, .refresh = %d,\n\t\t.image_desc = %s, .render_format = %s,\n\t\t.edid = %s, .tags = %d, .disabled = %d,\n\t},\n" $rules ($output.name | quote) ($output.scale | float64) $x $y $width $height $refresh $image $format ($output.edid | quote) $mask $disabled -}}
{{- end -}}
/* machine settings: begin */
#define DWL_RENDERER {{ $renderer | quote }}
#define DWL_RENDER_DEVICE {{ $settings.renderDevice | quote }}
#define DWL_MOUSE_NAME {{ $settings.mouse | quote }}
#define DWL_MOUSE_SPEED ({{ printf "%.6f" ($settings.sensitivity | float64) }})
#define DWL_XKB_LAYOUT {{ $settings.keyboardLayout | quote }}
#define DWL_XKB_OPTIONS {{ $settings.keyboardOptions | quote }}
/* machine settings: end */
/* output rules: begin */
static const MonitorRule monrules[] = {
{{ $rules }}	{
		.name = NULL, .mfact = 0.55f, .nmaster = 1, .scale = 1.0f,
		.lt = &layouts[0], .rr = WL_OUTPUT_TRANSFORM_NORMAL, .x = -1, .y = -1,
		.width = 0, .height = 0, .refresh = 0,
		.image_desc = NULL, .render_format = DRM_FORMAT_XRGB8888,
		.edid = NULL, .tags = 0, .disabled = 0,
	},
};
/* output rules: end */
