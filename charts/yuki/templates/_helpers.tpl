{{/* Validate the observability backend / subchart-toggle combination. */}}
{{- define "proxy.observability.validate" -}}
{{- $backend := .Values.observability.backend -}}
{{- if not (or (eq $backend "otlp") (eq $backend "groundcoverSensor")) -}}
{{- fail (printf "observability.backend must be either \"otlp\" or \"groundcoverSensor\", got %q" $backend) -}}
{{- end -}}
{{- if and (eq $backend "otlp") .Values.groundcover.enabled -}}
{{- fail "observability.backend is \"otlp\" but groundcover.enabled is true — set groundcover.enabled: false (the sensor subchart must be off for the OTLP backend)." -}}
{{- end -}}
{{- if and .Values.observability.groundcover.existingSecret.name (not .Values.observability.groundcover.existingSecret.key) -}}
{{- fail "observability.groundcover.existingSecret.name is set but existingSecret.key is empty — set the key name within that Secret (e.g. INGESTION_KEY)." -}}
{{- end -}}
{{- end -}}

{{/* OTel collector resource name. */}}
{{- define "proxy.otelCollectorName" -}}
{{- printf "%s-otel-collector" .Values.app.name -}}
{{- end -}}

{{/* Ingestion-key Secret name: existingSecret if set, else chart-managed. */}}
{{- define "proxy.groundcover.secretName" -}}
{{- with .Values.observability.groundcover.existingSecret.name -}}
{{- . -}}
{{- else -}}
{{- .Values.observability.groundcover.secretName -}}
{{- end -}}
{{- end -}}

{{/* Key within the ingestion-key Secret. */}}
{{- define "proxy.groundcover.secretKey" -}}
{{- if .Values.observability.groundcover.existingSecret.name -}}
{{- .Values.observability.groundcover.existingSecret.key -}}
{{- else -}}
INGESTION_KEY
{{- end -}}
{{- end -}}
