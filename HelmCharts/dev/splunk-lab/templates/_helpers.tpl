{{- define "splunk-lab.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "splunk-lab.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "splunk-lab.targetImage" -}}
{{ .Values.global.imageRegistry }}/{{ .Values.targetApp.image.repository }}:{{ .Values.targetApp.image.tag }}
{{- end }}

{{- define "splunk-lab.generatorImage" -}}
{{ .Values.global.imageRegistry }}/{{ .Values.loadGenerator.image.repository }}:{{ .Values.loadGenerator.image.tag }}
{{- end }}

{{- define "splunk-lab.controlImage" -}}
{{ .Values.global.imageRegistry }}/{{ .Values.controlPanel.image.repository }}:{{ .Values.controlPanel.image.tag }}
{{- end }}
