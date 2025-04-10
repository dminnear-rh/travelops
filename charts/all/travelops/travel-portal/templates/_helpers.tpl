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

NS="travel-portal"
DEPLOYMENTS=("travels" "travels-v1" "voyages" "voyages-v1" "viaggi" "viaggi-v1")

for deploy in "${DEPLOYMENTS[@]}"; do
  echo "🔍 Checking rollout status for ${deploy} in namespace ${NS}..."

  while true; do
    # Only include pods owned by the specific deployment
    PODS=$(oc get pods -n "${NS}" --no-headers | grep "${deploy}" || true)

    if [[ -z "$PODS" ]]; then
      echo "❗ No pods found for ${deploy}. Waiting..."
      sleep 10
      continue
    fi

    TOTAL=$(echo "$PODS" | wc -l)
    READY=$(echo "$PODS" | awk '$2 == $2' | grep -E '1/1|2/2' | wc -l)
    SIDECAR_COUNT=0

    for POD in $(echo "$PODS" | awk '{print $1}'); do
      CONTAINERS=$(oc get pod "$POD" -n "${NS}" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
      if echo "$CONTAINERS" | grep -q "istio-proxy"; then
        SIDECAR_COUNT=$((SIDECAR_COUNT + 1))
      fi
    done

    echo "📊 $deploy: Total=$TOTAL, Ready=$READY, Sidecars=$SIDECAR_COUNT"

    if [[ "$TOTAL" -gt 0 && "$TOTAL" -eq "$READY" && "$TOTAL" -eq "$SIDECAR_COUNT" ]]; then
      echo "✅ ${deploy} is fully rolled out with sidecars."
      break
    else
      echo "🔄 Restarting rollout for ${deploy} in ${NS}..."
      oc rollout restart deployment "${deploy}" -n "${NS}" || true
      sleep 15
    fi
  done
done

echo "🎉 All deployments in ${NS} are now injected and ready!"
{{- end }}
