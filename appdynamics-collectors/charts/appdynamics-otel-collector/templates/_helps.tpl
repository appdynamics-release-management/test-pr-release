{{/*
Expand the name of the chart.
*/}}
{{- define "appdynamics-otel-collector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
 Create a default fully qualified app name.
 We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
 If release name contains chart name it will be used as a full name.
*/}}
{{- define "appdynamics-otel-collector.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "appdynamics-otel-collector.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
Open telemetry operator assigns recommended labels like "app.kubernetes.io/instance" automatically, to avoid conflict,
we change to to use app.appdynamics.otel.collector.
*/}}
{{- define "appdynamics-otel-collector.labels" -}}
helm.sh/chart: {{ include "appdynamics-otel-collector.chart" . }}
{{ include "appdynamics-otel-collector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.appdynamics.otel.collector/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.appdynamics.otel.collector/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "appdynamics-otel-collector.selectorLabels" -}}
app.appdynamics.otel.collector/name: {{ include "appdynamics-otel-collector.name" . }}
app.appdynamics.otel.collector/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "appdynamics-otel-collector.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "appdynamics-otel-collector.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create service ports list, will be used to override default v1/Service ports also.
*/}}
{{- define "appdynamics-otel-collector.servicePorts" -}}
{{- if .Values.service.ports}}
{{- .Values.service.ports | toYaml}}
{{- end }}
{{- end}}


