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

{{/* Short env token for secret paths: staging→stg, production→prod, development→dev. */}}
{{- define "mcp.envShort" -}}
{{- $env := .Values.app.container.env.ENVIRONMENT | default "production" -}}
{{- if   eq $env "staging"     -}}stg
{{- else if eq $env "production"  -}}prod
{{- else if eq $env "development" -}}dev
{{- else -}}{{ fail (printf "mcp.envShort: unknown ENVIRONMENT %q (expected staging|production|development)" $env) }}
{{- end -}}
{{- end -}}

{{/* AWS Secrets Manager path for the MCP OAuth client creds: {envShort}/yuki-mcp/{account-id}. */}}
{{- define "mcp.secretName" -}}
{{- $acct := required "app.container.env.ACCOUNT_GUID is required when mcp.enabled" .Values.app.container.env.ACCOUNT_GUID -}}
{{- printf "%s/yuki-mcp/%s" (include "mcp.envShort" .) $acct -}}
{{- end -}}
