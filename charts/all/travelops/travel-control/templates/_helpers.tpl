{{/*
Expand the name of the chart.
*/}}
{{- define "travel-control.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "travel-control.fullname" -}}
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
{{- define "travel-control.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "travel-control.labels" -}}
helm.sh/chart: {{ include "travel-control.chart" . }}
{{ include "travel-control.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "travel-control.selectorLabels" -}}
app.kubernetes.io/name: {{ include "travel-control.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "travel-control.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "travel-control.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Proxy config for istio (indent 8)
*/}}
{{- define "travel-control.istioProxyConfig" -}}
proxy.istio.io/config: |
  tracing:
    zipkin:
      address: dev-collector.istio-system.svc.cluster.local:9411
    sampling: 100
    custom_tags:
      http.header.portal:
        header:
          name: portal
      http.header.device:
        header:
          name: device
      http.header.user:
        header:
          name: user
      http.header.travel:
        header:
          name: travel
{{- end }}

{{- define "travel-control.rolloutRestart" }}
#!/bin/bash

for apps in control; do
  NS=travel-control
  READY_COUNT=$(oc get pods -l app=${apps} --no-headers -n ${NS} | awk '$2 == "2/2"' | wc -l)

  while [[ ${READY_COUNT} -lt 1 ]]; do
    echo "🔄 Restarting deployment rollout for ${apps} in ${NS}"
    kubectl rollout restart deploy -l app=${apps} -n ${NS}
    sleep 10
    READY_COUNT=$(oc get pods -l app=${apps} --no-headers -n ${NS} | awk '$2 == "2/2"' | wc -l)
  done

  echo "✅ ${apps} in ${NS} is fully rolled out with sidecars."
done
{{- end }}
