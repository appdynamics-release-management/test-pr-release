{{/*
  Derived configuation from top level properties
*/}}
{{- define "appdynamics-otel-collector.derivedConfig" -}}
extensions:
  oauth2client:
    client_id: {{required ".clientId is required" .Values.clientId}}
{{- if .Values.clientSecret }}
    client_secret: {{ .Values.clientSecret }}
{{- else if .Values.clientSecretEnvVar }}
    client_secret: "${APPD_OTELCOL_CLIENT_SECRET}"
{{- end }}
    token_url: {{required ".tokenUrl is required" .Values.tokenUrl}}
exporters:
  otlphttp:
    metrics_endpoint: {{required ".endpoint is required" .Values.endpoint}}/v1/metrics
    traces_endpoint: {{.Values.endpoint}}/v1/trace
    logs_endpoint: {{.Values.endpoint}}/v1/logs
{{- end }}

{{- define "appdynamics-otel-collector.tlsConfig" -}}
{{- if .Values.global.tls.otelReceiver.settings }}
receivers:
  otlp:
    protocols:
      grpc:
        tls:
{{- deepCopy .Values.global.tls.otelReceiver.settings | toYaml | nindent 10}}
      http:
        tls:
{{- deepCopy .Values.global.tls.otelReceiver.settings | toYaml | nindent 10}}
{{- end }}
{{- if .Values.global.tls.otelExporter.settings }}
extensions:
  oauth2client:
    tls:
{{- deepCopy .Values.global.tls.otelExporter.settings | toYaml | nindent 6}}    
exporters:
  otlphttp:
    tls:
{{- deepCopy .Values.global.tls.otelExporter.settings | toYaml | nindent 6}}    
{{- end }}
{{- end }}

{{/*
  Generate the secret environment variable for OAuth2.0
*/}}
{{- define "appdynamics-otel-collector.clientSecretEnvVar" -}}
{{- if .Values.clientSecretEnvVar -}}
name: APPD_OTELCOL_CLIENT_SECRET
{{- .Values.clientSecretEnvVar | toYaml | nindent 0}}
{{- end }}
{{- end }}

{{/*
  Generate the spec.config section of the value file by 
  1) Deriving ouath2 yaml block and merging it to default config
  2) Deriving the otlphttp endpoint block it to default config
  3) Merging user overrides  to default config
*/}}

{{- define "appdynamics-otel-collector.valueConfig" -}}
{{- if not .Values.spec.config }}
{{- $otelConfig := tpl (get .Values "config" | toYaml) . | fromYaml}}
{{- $mergedConfig := mustMergeOverwrite $otelConfig (include "appdynamics-otel-collector.derivedConfig" . | fromYaml )}}
{{- $mergedConfig := mustMergeOverwrite $mergedConfig (include "appdynamics-otel-collector.tlsConfigFromSecrets" . | fromYaml ) }}
{{- $mergedConfig := mustMergeOverwrite $mergedConfig (include "appdynamics-otel-collector.tlsConfig" . | fromYaml ) }}
{{- if .Values.configOverride }}
{{- $mergedConfig := mustMergeOverwrite $mergedConfig (deepCopy .Values.configOverride)}}
{{- end }}
{{- $_ := set .Values.spec "config" ($mergedConfig | toYaml) }}
{{- end }}
{{- if .Values.clientSecretEnvVar -}}
{{- if .Values.spec.env -}}
{{- $appendEnv := append .Values.spec.env (include "appdynamics-otel-collector.clientSecretEnvVar" . | fromYaml ) }}
{{- $_ := set .Values.spec "env" $appendEnv }}
{{- else}}
{{  $_ := set .Values.spec "env" (include "appdynamics-otel-collector.clientSecretEnvVar" . | fromYaml | list)}}
{{- end }}
{{- end }}
{{- .Values.spec | toYaml }}
{{- end }}


{{/*
  Set service.ports into spec.ports in the value file.
  If the spec.ports is already set, the service.ports section won't take any effect.
*/}}
{{- define "appdynamics-otel-collector.valueServicePorts" -}}
{{- if not .Values.spec.ports }}
{{- $_ := set .Values.spec "ports" .Values.service.ports }}
{{- end }}
{{- .Values.spec | toYaml }}
{{- end }}

{{/*
  Set serviceAccount.name into spec.serviceAccount in the value file.
  If the spec.serviceAccount is already set, the serviceAccount.name won't take any effect.
  If neither spec.serviceAccount and serviceAccount.name are set, the default value will be populated to spec.serviceAccount.
*/}}
{{- define "appdynamics-otel-collector.valueServiceAccount" -}}
{{- if not .Values.spec.serviceAccount }}
{{- $_ := set .Values.spec "serviceAccount" (.Values.serviceAccount.name | default (include "appdynamics-otel-collector.serviceAccountName" .)) }}
{{- end }}
{{- .Values.spec | toYaml }}
{{- end}}


{{- define "appdynamics-otel-collector.serverDefaultPaths" -}}
{{ $path := .path | default "/etc/otel/certs/receiver"}}
{{- if .secretKeys.caCert}}
ca_file: {{$path}}/{{.secretKeys.caCert}}
client_ca_file: {{$path}}/{{.secretKeys.caCert}}
{{- end}}
cert_file: {{$path}}/{{.secretKeys.tlsCert}}
key_file: {{$path}}/{{.secretKeys.tlsKey}}
{{- end}}

{{- define "appdynamics-otel-collector.clientDefaultPaths" -}}
{{ $path := .path | default "/etc/otel/certs/exporter"}}
{{- if .secretKeys.caCert}}
ca_file: {{$path}}/{{.secretKeys.caCert}}
{{- end}}
cert_file: {{$path}}/{{.secretKeys.tlsCert}}
key_file: {{$path}}/{{.secretKeys.tlsKey}}
{{- end}}


{{- define "appdynamics-otel-collector.secrets" -}}
secret:
  secretName: {{.secretName}}
  items:
  {{- if .secretKeys.caCert}}
    - key: {{.secretKeys.caCert}}
      path: {{.secretKeys.caCert}}
  {{- end }}
    - key: {{required ".secretKeys.tlsCert is required" .secretKeys.tlsCert}}
      path: {{.secretKeys.tlsCert}}
    - key: {{required ".secretKeys.tlsKey is required" .secretKeys.tlsKey}}
      path: {{.secretKeys.tlsKey}}
{{- end}}

{{/*
  mount the tls cert files in case tls certs are derived from k8s secrets.
*/}}

{{- define "appdynamics-otel-collector.valueTLSVolume" -}}
{{- if or .Values.global.tls.otelReceiver.secret .Values.global.tls.otelExporter.secret }}
volumeMounts:
{{- with  .Values.global.tls.otelReceiver.secret}}
{{ $path := .path | default "/etc/otel/certs/receiver"}}
- name: tlsotelreceiversecrets
  mountPath: {{$path}}
{{- end}}
{{- with  .Values.global.tls.otelExporter.secret}}
{{ $path := .path | default "/etc/otel/certs/exporter"}}
- name: tlsotelexportersecrets
  mountPath: {{$path}}
{{- end}}

volumes:
{{- with  .Values.global.tls.otelReceiver.secret}}
- name: tlsotelreceiversecrets
{{- (include "appdynamics-otel-collector.secrets" .)  | nindent 2}}
{{- end}}
{{- with .Values.global.tls.otelExporter.secret}}
- name: tlsotelexportersecrets
{{- (include "appdynamics-otel-collector.secrets" .)  | nindent 2}}
{{- end}}
{{- end}}
{{- end}}

{{/*
  Generate tls cert paths from  volume mounts dervied from secrets
*/}}
{{- define "appdynamics-otel-collector.tlsConfigFromSecrets" -}}
{{- with .Values.global.tls.otelReceiver.secret}}
receivers:
  otlp:
    protocols:
      grpc:
        tls:
{{- (include "appdynamics-otel-collector.serverDefaultPaths" .)  | nindent 10}}
      http:
        tls:
{{- (include "appdynamics-otel-collector.serverDefaultPaths" .)  | nindent 10}}
{{- end }}
{{- with .Values.global.tls.otelExporter.secret }}
extensions:
  oauth2client:
    tls:
{{- (include "appdynamics-otel-collector.clientDefaultPaths" .)  | nindent 6}}
exporters:
  otlphttp:
    tls:
{{- (include "appdynamics-otel-collector.clientDefaultPaths" .)  | nindent 6}}
{{- end }}
{{- end }}

{{/*
   Combine the sections into spec.
*/}}
{{- define "appdynamics-otel-collector.spec" -}}
{{- $spec := include "appdynamics-otel-collector.valueConfig" . | fromYaml | deepCopy }}
{{- $spec := include "appdynamics-otel-collector.valueTLSVolume" . | fromYaml | deepCopy | mustMergeOverwrite $spec }}
{{- $spec := include "appdynamics-otel-collector.valueServicePorts" . | fromYaml | deepCopy | mustMergeOverwrite $spec }}
{{- $spec := include "appdynamics-otel-collector.valueServiceAccount" . | fromYaml | deepCopy | mustMergeOverwrite $spec }}
{{- $spec | toYaml}}
{{- end}}