# Upgrading

## Datadog fully removed (this version)

Yuki has closed its Datadog account. This version deletes the
`SERILOG_DATADOG_ENABLED` escape hatch and the `datadogApm` tracing block
entirely — there is no supported way to route logs or traces to Datadog via
this chart anymore, even by setting `app.container.env.SERILOG_DATADOG_ENABLED`
explicitly. The proxy image itself no longer has a Datadog sink to enable, so
the flag was already a no-op before this cleanup.

**Impact:** any self-hosted proxy still setting `SERILOG_DATADOG_ENABLED: true`
should remove that value — it does nothing on this or any recent proxy image.
Yuki's fully-hosted proxies set no observability values and are unaffected.

The "Datadog → Groundcover" notes below describe that prior migration and are
kept for historical context only; the rollback path they describe no longer
applies since Datadog support has since been deleted outright.

## Datadog → Groundcover (observability) [historical]

This version replaces the Datadog Serilog log sink with Groundcover. The chart
now forces `SERILOG_DATADOG_ENABLED=false`, and observability is selected via
`observability.backend` (`groundcoverSensor` default, or `otlp`).

**Impact:** a self-hosted proxy that relied on the old chart default for Datadog
logging stops shipping to Datadog after upgrade. (A proxy that sets
`SERILOG_DATADOG_ENABLED: true` *explicitly* keeps Datadog — that value still
wins.) Yuki's fully-hosted prod/staging proxies set no observability values, so
they only get a zero-downtime rolling restart — no behavior change.

### Migrating a self-hosted proxy that uses Datadog

You need a Groundcover ingestion key. Recommended (run both, then cut over):

1. **Parallel** — upgrade keeping Datadog on:
   ```yaml
   global: { groundcover_token: <key> }
   groundcover: { enabled: true, clusterId: <unique> }
   app: { container: { env: { SERILOG_DATADOG_ENABLED: true } } }  # keeps Datadog
   ```
   Verify the cluster appears in Groundcover.
2. **Cut over** — remove the `SERILOG_DATADOG_ENABLED` line and `helm upgrade`
   again. Datadog stops; Groundcover remains.

Direct cutover: skip step 1 and ensure no explicit `SERILOG_DATADOG_ENABLED: true`
remains — the eBPF sensor captures immediately, so the gap is negligible.

**Prereqs (sensor backend):** the cluster must allow the privileged eBPF sensor
DaemonSet and have capacity for the sensor stack.

**Rollback:** `helm rollback <release>` reverts the version (Datadog back on,
sensor removed).
