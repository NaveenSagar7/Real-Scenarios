{{- define "meter-reading-service.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "meter-reading-service.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "meter-reading-service.labels" -}}
app.kubernetes.io/name: {{ include "meter-reading-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "meter-reading-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "meter-reading-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
