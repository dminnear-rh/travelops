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

RUNNING=2
for apps in travels voyages viaggi;  do
    NS=travel-portal
    COUNT=$(oc get pods -l app=${apps} --no-headers -n ${NS} | awk '{print $2}' | awk -F/ '{print $1}')
  while [[ ${COUNT} != 2 ]]; do
    sleep 5
    echo "restarting deployment rollout for ${apps} in ${NS}"
    echo "Running: kubectl rollout restart deploy -l app=${apps} -n ${NS}"
    kubectl rollout restart deploy -l app=${apps} -n ${NS}
    sleep 15
    COUNT=$(oc get pods -l app=${apps} --no-headers -n ${NS} | awk '{print $2}' | awk -F/ '{print $1}')
    done
    echo "done"

  echo "All Set, no restart required in ${NS}"
done
{{- end }}
