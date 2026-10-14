{{- /* Shared settings with this machine's saved sections, or its installer answers. */ -}}
{{- $saved := printf "dwl-machines/%s.h" (includeTemplate "dwl-config-profile" .) -}}
{{- $machine := "" -}}
{{- if stat (joinPath .chezmoi.sourceDir $saved) -}}
{{- $machine = include $saved -}}
{{- else -}}
{{- $machine = includeTemplate "dwl-machine.h" . -}}
{{- end -}}
{{- $config := include "dot_config/dwl/config.def.h" -}}
{{- range $section := list "machine settings" "output rules" -}}
{{- $pattern := printf `(?s)/\* %s: begin \*/.*?/\* %s: end \*/` $section $section -}}
{{- if ne (len (regexFindAll $pattern $config -1)) 1 -}}
{{- fail (printf "config.def.h needs exactly one %s section" $section) -}}
{{- end -}}
{{- $parts := regexFindAll $pattern $machine -1 -}}
{{- if ne (len $parts) 1 -}}
{{- fail (printf "%s needs exactly one %s section" $saved $section) -}}
{{- end -}}
{{- $config = regexReplaceAllLiteral $pattern $config (index $parts 0) -}}
{{- end -}}
{{- $config -}}
