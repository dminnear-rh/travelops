{{/*
Expand the name of the chart.
*/}}
{{- define "travel-portal.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "travel-portal.fullname" -}}
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
{{- define "travel-portal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "travel-portal.labels" -}}
helm.sh/chart: {{ include "travel-portal.chart" . }}
{{ include "travel-portal.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "travel-portal.selectorLabels" -}}
app.kubernetes.io/name: {{ include "travel-portal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "travel-portal.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "travel-portal.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "travel-portal.istioProxyConfig" -}}
proxy.istio.io/config: |
  tracing:
    zipkin:
      address: zipkin.istio-system:9411
    sampling: 10
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
{{- end}}

{{- define "travel-portal.rolloutRestart" }}
#!/bin/bash

set -euo pipefail

NS="travel-portal"

for app in travels voyages viaggi; do
  echo "Checking rollout status for ${app} in namespace ${NS}..."

  while true; do
    ALL_PODS=$(oc get pods -n ${NS} -l app=${app} --field-selector=status.phase=Running --no-headers | wc -l)
    READY_PODS=$(oc get pods -n ${NS} -l app=${app} --no-headers | awk '$2 == $2' | awk '{print $2}' | grep -c '^1/1\|2/2$')

    # Optional: Check for presence of sidecar container
    SIDECARS_PRESENT=$(oc get pods -n ${NS} -l app=${app} -o json | jq '[.items[] | .spec.containers[].name | select(. == "istio-proxy")]' | wc -l)

    if [[ "${ALL_PODS}" -gt 0 && "${ALL_PODS}" -eq "${READY_PODS}" && "${SIDECARS_PRESENT}" -ge "${ALL_PODS}" ]]; then
      echo "✅ ${app} is fully rolled out with sidecars."
      break
    else
      echo "🔄 Waiting for ${app} to be fully ready with sidecars..."
      echo "Restarting rollout for ${app} in ${NS}..."
      oc rollout restart deploy -l app=${app} -n ${NS}
      sleep 15
    fi
  done
done

echo "🎉 All apps in travel-portal are now injected and ready!"
{{- end }}
