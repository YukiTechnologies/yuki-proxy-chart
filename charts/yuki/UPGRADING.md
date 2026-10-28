# Upgrading

## Eviction and consolidation hardening

Proxy and passthrough pods now carry an ephemeral-storage request and limit, a
non-preempting PriorityClass, a `karpenter.sh/do-not-disrupt: "true"` annotation
and a soft one-pod-per-node spread, after a hosted proxy pod was hard-evicted for
*node* disk pressure it did not cause and its replacement was consolidated away
two minutes later. Upgrading rolls both Deployments once.

**Impact:**
- The chart creates a cluster-scoped `PriorityClass` named
  `<app.name>-<namespace>`. If whoever runs `helm upgrade` cannot create
  cluster-scoped resources, set `priorityClass.create: false`, optionally with
  `priorityClass.name` pointing at a class that already exists.
- On Karpenter / EKS Auto Mode clusters, a node running a proxy or passthrough
  pod is no longer consolidated or drifted while the pod runs. That protects
  availability at a cost: an underutilized node stays at its size. Set
  `karpenter.doNotDisrupt: false` to opt out, ideally together with
  `podDisruptionBudget.enabled: true`, which slows disruption instead of
  blocking it.
- The kubelet evicts a pod whose ephemeral-storage use passes the new limit
  (`resources.limits.ephemeral-storage`, 512Mi). Logs go to stdout and the proxy
  writes little else, so raise it only if your image writes locally.

## DuckDB engine runs Duckling (DuckDB v2)

`fabric.engines.duckdb` now deploys Duckling, the Python DuckDB v2 service from
yuki-fabric/Duckling. Duckling replaces the DuckDB CLI + httpserver image. The
chart no longer renders a `.duckdbrc`:

- The Secret holds `init.sql` (plain SQL, mounted at `/etc/duckling/init.sql`)
  and `api-key`. Duckling reads the key from the `DUCKLING_API_KEY` env, not
  from the init SQL.
- Pods listen on 9999. The Service port (`fabric.engines.duckdb.port`) and the
  proxy's `QUERY_FEDERATION_DUCKDB_URL` are unchanged.
- An init SQL error now fails the pod's startup. The old CLI only printed it.

**Impact:** `fabric.engines.duckdb.image` must be a Duckling image.
Pre-Duckling `duckdb:*` images crash on this chart, and Duckling images crash
on older charts. Ship the chart and the image pin (terraform-infra
`images.duckdb`) together. Readiness probes keep the old pods serving until the
new ones pass, and the proxy falls back to Snowflake while DuckDB is down.

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
