{{- /* One-time installer seed. The user's config.h is never a managed output. */ -}}
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{- $config := include "dot_config/dwl/config.def.h" -}}
{{- $renderer := $settings.renderer -}}
{{- if eq $renderer "auto" }}{{ $renderer = "" }}{{ end -}}
{{- $config = regexReplaceAll `(?m)^#define DWL_RENDERER .*` $config (printf "#define DWL_RENDERER %s" ($renderer | quote)) -}}
{{- $config = regexReplaceAll `(?m)^#define DWL_RENDER_DEVICE .*` $config (printf "#define DWL_RENDER_DEVICE %s" ($settings.renderDevice | quote)) -}}
{{- $config = regexReplaceAll `(?m)^#define DWL_MOUSE_NAME .*` $config (printf "#define DWL_MOUSE_NAME %s" ($settings.mouse | quote)) -}}
{{- $config = regexReplaceAll `(?m)^#define DWL_MOUSE_SPEED .*` $config (printf "#define DWL_MOUSE_SPEED (%.6f)" ($settings.sensitivity | float64)) -}}
{{- $config = regexReplaceAll `(?m)^\s*\.layout = .*` $config (printf "\t.layout = %s," ($settings.keyboardLayout | quote)) -}}
{{- $config = regexReplaceAll `(?m)^\s*\.options = .*` $config (printf "\t.options = %s," ($settings.keyboardOptions | quote)) -}}
{{- $rules := "/* output rules: begin */\nstatic const MonitorRule monrules[] = {\n" -}}
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
{{- $rules = printf "%s\t{\n\t\t.name = NULL, .mfact = 0.55f, .nmaster = 1, .scale = 1.0f,\n\t\t.lt = &layouts[0], .rr = WL_OUTPUT_TRANSFORM_NORMAL, .x = -1, .y = -1,\n\t\t.width = 0, .height = 0, .refresh = 0,\n\t\t.image_desc = NULL, .render_format = DRM_FORMAT_XRGB8888,\n\t\t.edid = NULL, .tags = 0, .disabled = 0,\n\t},\n};\n/* output rules: end */" $rules -}}
{{- regexReplaceAll `(?s)/\* output rules: begin \*/.*?/\* output rules: end \*/` $config $rules -}}
