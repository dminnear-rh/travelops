{{/*
Expand the name of the chart.
*/}}
{{- define "travel-agency.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "travel-agency.fullname" -}}
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
{{- define "travel-agency.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "travel-agency.labels" -}}
{{ include "travel-agency.selectorLabels" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "travel-agency.selectorLabels" -}}
{{- end }}

{{/*
Proxy config for istio (indent 8)
*/}}
{{- define "travel-agency.istioProxyConfig" -}}
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
{{- end }}

{{- define "travel-agency.mysqlEnv" -}}
- name: MYSQL_USER
  value: "root"
- name: MYSQL_PASSWORD
  valueFrom:
    secretKeyRef:
      name: mysql-credentials
      key: rootpasswd
- name: MYSQL_DATABASE
  value: "test"
{{- end }}

{{- define "travel-agency.rolloutRestart" }}
#!/bin/bash

NS="travel-agency"
DEPLOYMENTS=("cars-v1" "discounts-v1" "flights-v1" "hotels-v1" "insurances-v1" "travels-v1")

echo "🔄 Restarting all deployments in $NS to trigger sidecar injection..."

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

echo "🎉 All deployments in $NS are now injected and ready!"
{{- end }}
