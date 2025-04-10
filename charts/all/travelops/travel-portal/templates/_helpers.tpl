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

echo "🔄 Restarting all deployments to trigger sidecar injection..."

for deploy in "${DEPLOYMENTS[@]}"; do
  oc rollout restart deployment "$deploy" -n "$NS"
done

echo "⏳ Waiting for pods to be ready and injected..."

for deploy in "${DEPLOYMENTS[@]}"; do
  echo "🔍 Verifying rollout and injection for $deploy..."

  while true; do
    PODS=$(oc get pods -n "$NS" -l app="${deploy%%-v1}" --no-headers | grep "$deploy" || true)

    if [[ -z "$PODS" ]]; then
      echo "❗ No pods found for $deploy yet. Waiting..."
      sleep 10
      continue
    fi

    TOTAL=0
    READY=0
    SIDECAR=0

    for pod in $(echo "$PODS" | awk '{print $1}'); do
      ((TOTAL++))

      # Check Ready
      READY_CONTAINERS=$(oc get pod "$pod" -n "$NS" -o jsonpath='{.status.containerStatuses[*].ready}' 2>/dev/null || echo "")
      if echo "$READY_CONTAINERS" | grep -q "true"; then
        ((READY++))
      fi

      # Check istio-proxy
      CONTAINERS=$(oc get pod "$pod" -n "$NS" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || echo "")
      if echo "$CONTAINERS" | grep -q "istio-proxy"; then
        ((SIDECAR++))
      fi
    done

    echo "📊 $deploy: Total=$TOTAL, Ready=$READY, Sidecars=$SIDECAR"

    if [[ "$TOTAL" -gt 0 && "$TOTAL" -eq "$READY" && "$TOTAL" -eq "$SIDECAR" ]]; then
      echo "✅ $deploy is fully rolled out with sidecars."
      break
    fi

    sleep 10
  done
done

echo "🎉 All deployments restarted and verified with sidecar injection!"
{{- end }}
