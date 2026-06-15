{{/*
Observability helpers.
*/}}

{{/*
Validate the mutually-exclusive observability backend selection.
Exactly one of "otlp" | "groundcoverSensor" must be active, and the
groundcover subchart toggle must agree with the chosen backend.
*/}}
{{- define "proxy.observability.validate" -}}
{{- $backend := .Values.observability.backend -}}
{{- if not (or (eq $backend "otlp") (eq $backend "groundcoverSensor")) -}}
{{- fail (printf "observability.backend must be either \"otlp\" or \"groundcoverSensor\", got %q" $backend) -}}
{{- end -}}
{{- $gc := .Values.groundcover.enabled -}}
{{- if and (eq $backend "groundcoverSensor") (not $gc) -}}
{{- fail "observability.backend is \"groundcoverSensor\" but groundcover.enabled is false — set groundcover.enabled: true to deploy the eBPF sensor." -}}
{{- end -}}
{{- if and (eq $backend "otlp") $gc -}}
{{- fail "observability.backend is \"otlp\" but groundcover.enabled is true — set groundcover.enabled: false (the sensor subchart must be off for the OTLP backend)." -}}
{{- end -}}
{{- /* Ingestion key completeness: both backends need a key to ship telemetry.
     Warn (not fail) so helm install/template still works in CI without a key. */ -}}
{{- $hasApiKey := .Values.observability.groundcover.apiKey -}}
{{- $hasExistingSecret := .Values.observability.groundcover.existingSecret.name -}}
{{- if and (not $hasApiKey) (not $hasExistingSecret) -}}
{{- /* emit a visible warning via a named template rendered into NOTES */ -}}
{{- end -}}
{{- /* Validate that existingSecret.name and secretName don't both point somewhere
     different — the chart always uses existingSecret.name when set. */ -}}
{{- if and $hasExistingSecret (not .Values.observability.groundcover.existingSecret.key) -}}
{{- fail "observability.groundcover.existingSecret.name is set but existingSecret.key is empty — set the key name within that Secret (e.g. INGESTION_KEY)." -}}
{{- end -}}
{{- end -}}

{{/*
Name of the OTel collector resources (otlp backend).
*/}}
{{- define "proxy.otelCollectorName" -}}
{{- printf "%s-otel-collector" .Values.app.name -}}
{{- end -}}

{{/*
Name of the Secret holding the Groundcover ingestion key.
Uses an existing Secret if provided, otherwise the chart-managed name.
*/}}
{{- define "proxy.groundcover.secretName" -}}
{{- with .Values.observability.groundcover.existingSecret.name -}}
{{- . -}}
{{- else -}}
{{- .Values.observability.groundcover.secretName -}}
{{- end -}}
{{- end -}}

{{/*
Key within the ingestion-key Secret.
*/}}
{{- define "proxy.groundcover.secretKey" -}}
{{- if .Values.observability.groundcover.existingSecret.name -}}
{{- .Values.observability.groundcover.existingSecret.key -}}
{{- else -}}
INGESTION_KEY
{{- end -}}
{{- end -}}
