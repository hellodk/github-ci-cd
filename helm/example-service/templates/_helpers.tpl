{{- define "example-service.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "example-service.labels" -}}
app.kubernetes.io/name: example-service
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "example-service.selectorLabels" -}}
app.kubernetes.io/name: example-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "example-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "example-service.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
