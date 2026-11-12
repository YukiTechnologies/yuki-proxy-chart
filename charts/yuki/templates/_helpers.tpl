{{/* Duckling's init SQL, run once at startup. Hashed by the pod template: no metadata. */}}
{{- define "proxy.duckdb.initSql" -}}
{{- $duckdb := .Values.fabric.engines.duckdb -}}
{{- list
  "LOAD iceberg;"
  "LOAD httpfs;"
  "SET enable_logging = true;"
  (printf "SET threads=%d;" (int64 $duckdb.threads))
  (printf "SET memory_limit='%s';" (replace "'" "''" (required "fabric.engines.duckdb.memoryLimit is required" $duckdb.memoryLimit)))
  "CREATE OR REPLACE SECRET secret (TYPE s3, PROVIDER credential_chain, VALIDATION 'none');"
  | join "\n" -}}
{{- with $duckdb.maxTempDirectorySize }}
{{- printf "\nSET max_temp_directory_size='%s';" (replace "'" "''" .) -}}
{{- end -}}
{{- end -}}

{{- define "proxy.fabric.catalogEndpoint" -}}
{{- $catalog := .Values.fabric.catalog | default dict -}}
{{- $host := $catalog.endpoint -}}
{{- if not $host -}}
{{- $proxyHost := required "fabric.catalog.endpoint is required when PROXY_HOST is unset" (.Values.app.container.env).PROXY_HOST -}}
{{- $host = printf "%s/polaris/api/catalog" (trimSuffix "/" $proxyHost) -}}
{{- end -}}
{{- $trimmed := trimSuffix "/" $host -}}
{{- if not $trimmed -}}
{{- fail "fabric.catalog.endpoint normalises to empty" -}}
{{- end -}}
{{- $trimmed -}}
{{- end -}}

{{/* Validate fabric.enabled against the engines actually in use. */}}
{{- define "proxy.fabric.validate" -}}
{{- $fabric := .Values.fabric | default dict -}}
{{- $allowed := list "duckdb" "starrocks" -}}
{{- $inUse := list -}}
{{- range $name, $engine := ($fabric.engines | default dict) -}}
{{- if not (has $name $allowed) -}}
{{- fail (printf "fabric.engines: unknown engine %q, expected one of: %s" $name (join ", " $allowed)) -}}
{{- end -}}
{{- $cfg := default dict $engine -}}
{{- if or $cfg.deploy $cfg.env $cfg.envFromSecrets -}}
{{- $inUse = append $inUse $name -}}
{{- end -}}
{{- end -}}
{{- if and (not $fabric.enabled) (($fabric.sqlTranslator | default dict).enabled) -}}
{{- fail "fabric.enabled is false but fabric.sqlTranslator.enabled is true" -}}
{{- end -}}
{{- if $fabric.enabled -}}
{{- if not $inUse -}}
{{- fail (printf "fabric.enabled is true but no engine is in use: set deploy, or give one connection settings. Expected one of: %s" (join ", " $allowed)) -}}
{{- end -}}
{{- else -}}
{{- if $inUse -}}
{{- fail (printf "fabric.enabled is false but these engines are configured: %s" (join ", " $inUse)) -}}
{{- end -}}
{{- end -}}
{{- end -}}

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

{{/* Time the preStop drain calls may take in total: one full drain (+5s curl margin), or the minimum hold
     plus a 10s second drain (5s stable-zero window + 5s margin). */}}
{{- define "proxy.preStop.drainBudget" -}}
{{- max (add (.Values.app.drainTimeoutSeconds | int) 5) (add (.Values.app.drainMinHoldSeconds | int) 10) -}}
{{- end -}}

{{/* Fail the render if the shutdown budget cannot fit inside the pod's grace period. */}}
{{- define "proxy.shutdown.validate" -}}
{{- $grace := .Values.app.terminationGracePeriodSeconds | int -}}
{{- $shutdown := .Values.app.shutdownTimeoutSeconds | int -}}
{{- /* preStop is whichever is longer: the drain calls or the failure fallback. */ -}}
{{- $preStop := max (include "proxy.preStop.drainBudget" . | int) (.Values.app.drainFallbackSeconds | int) -}}
{{- if ge (add $preStop $shutdown) $grace -}}
{{- fail (printf "preStop worst case (%ds: max of drainTimeoutSeconds+5, drainMinHoldSeconds+10 and drainFallbackSeconds) + app.shutdownTimeoutSeconds (%d) must be less than app.terminationGracePeriodSeconds (%d), or kubelet SIGKILLs the pod mid-drain." $preStop $shutdown $grace) -}}
{{- end -}}
{{- /* The two sidecar workloads have no drain endpoint, so they sleep out the LB window; leave them room to exit. */ -}}
{{- if .Values.passthrough.enabled -}}
{{- $pSleep := .Values.passthrough.drainSleepSeconds | int -}}
{{- $pGrace := .Values.passthrough.terminationGracePeriodSeconds | int -}}
{{- if gt (add $pSleep 15) $pGrace -}}
{{- fail (printf "passthrough.drainSleepSeconds (%d) leaves under 15s to shut down before passthrough.terminationGracePeriodSeconds (%d)." $pSleep $pGrace) -}}
{{- end -}}
{{- end -}}
{{- if .Values.mcp.enabled -}}
{{- $mSleep := .Values.mcp.drainSleepSeconds | int -}}
{{- $mGrace := .Values.mcp.terminationGracePeriodSeconds | int -}}
{{- if gt (add $mSleep 15) $mGrace -}}
{{- fail (printf "mcp.drainSleepSeconds (%d) leaves under 15s to shut down before mcp.terminationGracePeriodSeconds (%d)." $mSleep $mGrace) -}}
{{- end -}}
{{- end -}}
{{- if .Values.mcpConnector.enabled -}}
{{- $cSleep := .Values.mcpConnector.drainSleepSeconds | int -}}
{{- $cGrace := .Values.mcpConnector.terminationGracePeriodSeconds | int -}}
{{- $cDereg := .Values.mcpConnector.deregistrationDelaySeconds | int -}}
{{- if gt (add $cSleep 15) $cGrace -}}
{{- fail (printf "mcpConnector.drainSleepSeconds (%d) leaves under 15s to shut down before mcpConnector.terminationGracePeriodSeconds (%d)." $cSleep $cGrace) -}}
{{- end -}}
{{- if lt $cSleep $cDereg -}}
{{- fail (printf "mcpConnector.drainSleepSeconds (%d) is shorter than mcpConnector.deregistrationDelaySeconds (%d), so the ALB still routes to a stopping pod." $cSleep $cDereg) -}}
{{- end -}}
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

{{/* Snowflake URL the passthrough forwards to; trailing "" avoids "<no value>" when unset. */}}
{{- define "proxy.passthrough.snowflakeUrl" -}}
{{- or .Values.passthrough.snowflakeHost .Values.app.container.env.PROXY_HOST "" -}}
{{- end -}}

{{/* BigQuery URL the passthrough forwards to — same fixed Google endpoint for every account. */}}
{{- define "proxy.passthrough.bigqueryUrl" -}}
{{- or .Values.passthrough.bigqueryHost .Values.app.container.env.BIGQUERY_HOST "" -}}
{{- end -}}

{{/* Whichever backend is configured — BigQuery takes precedence, matching ClientProxy's own route order. */}}
{{- define "proxy.passthrough.upstreamUrl" -}}
{{- include "proxy.passthrough.bigqueryUrl" . | default (include "proxy.passthrough.snowflakeUrl" .) -}}
{{- end -}}

{{/* Real upstream host — the client's request instead targets Yuki's hosted domain, so this is what gets rewritten in. */}}
{{- define "proxy.passthrough.upstreamHostHeader" -}}
{{- (include "proxy.passthrough.upstreamUrl" . | urlParse).host -}}
{{- end -}}

{{/* Env token for secret paths: staging→stg, production→prod, development→dev. */}}
{{- define "mcp.envShort" -}}
{{- $env := required "app.container.env.ENVIRONMENT is required when mcp.enabled" .Values.app.container.env.ENVIRONMENT | lower -}}
{{- if   eq $env "staging"     -}}stg
{{- else if eq $env "production"  -}}prod
{{- else if eq $env "development" -}}dev
{{- else -}}{{ fail (printf "mcp.envShort: unknown ENVIRONMENT %q (expected staging|production|development)" $env) }}
{{- end -}}
{{- end -}}

{{/* Secrets Manager path for MCP OAuth client creds. */}}
{{- define "mcp.secretName" -}}
{{- $acct := required "app.container.env.ACCOUNT_GUID is required when mcp.enabled" .Values.app.container.env.ACCOUNT_GUID -}}
{{- printf "%s/yuki-mcp/%s" (include "mcp.envShort" .) $acct -}}
{{- end -}}

{{/* The label is supplied by the deployment, never derived here, so DNS and the settings secret stay in step with its source. */}}
{{- define "mcpConnector.hostLabel" -}}
{{- $label := required "mcpConnector.hostLabel is required when mcpConnector.enabled" .Values.mcpConnector.hostLabel -}}
{{- if not (regexMatch "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$" $label) -}}
{{- fail (printf "mcpConnector.hostLabel %q is not a lower-case DNS label of at most 63 chars" $label) -}}
{{- end -}}
{{- $label -}}
{{- end -}}

{{- define "mcpConnector.host" -}}
{{- $domain := required "mcpConnector.domain is required when mcpConnector.enabled" .Values.mcpConnector.domain -}}
{{- if not (regexMatch "^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$" $domain) -}}
{{- fail (printf "mcpConnector.domain %q is not a lower-case DNS name" $domain) -}}
{{- end -}}
{{- $host := printf "%s.mcp.%s" (include "mcpConnector.hostLabel" .) $domain -}}
{{- if gt (len $host) 253 -}}
{{- fail (printf "mcpConnector host %q is longer than the 253-char DNS limit" $host) -}}
{{- end -}}
{{- $host -}}
{{- end -}}

{{- define "mcpConnector.yukiProxyHost" -}}
{{- .Values.mcpConnector.yukiProxyHost | default (printf "http://%s:%v" .Values.app.name .Values.app.service.port) -}}
{{- end -}}

{{- define "mcpConnector.settingsSecretName" -}}
{{- printf "%s/mcp-connector/%s" (include "mcp.envShort" .) (include "mcpConnector.hostLabel" .) -}}
{{- end -}}

{{/* ALB names are 32 chars max: 19 of the namespace, then the account id prefix keeps siblings apart. */}}
{{- define "mcpConnector.loadBalancerName" -}}
{{- $accountPrefix := .Values.app.container.env.ACCOUNT_GUID | replace "-" "" | trunc 8 -}}
{{- printf "%s-%s-mcp" (.Values.namespace | trunc 19 | trimSuffix "-") $accountPrefix -}}
{{- end -}}
