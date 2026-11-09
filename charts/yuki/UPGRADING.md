# Upgrading

## Catalog databases are optional

Duckling gets the catalog endpoint as `DUCKLING_CATALOG_ENDPOINT` and attaches each database a
query names (`X-Yuki-Catalog-Databases`, from the Go proxy) on that role's first query naming it.
`fabric.catalog.databases` is now optional; each one listed is still attached up front.

**Impact:** none for proxies that list their databases. Leaving the list out needs a Duckling image
that reads the header (yuki-fabric#26) and a Go proxy that sends it (go-yuki-proxies#77);
otherwise queries can't find their tables.

## Duckling reads the catalog with each query's token

Duckling reads the Iceberg catalog with the token each query brings for its role, not a PAT:

- The init SQL's catalog secret is `TOKEN '${QUERY_FEDERATION_CATALOG_TOKEN}'`, which
  Duckling fills in for each role's database.
- `fabric.catalog.role` and `fabric.catalog.secret` are gone, with the `<app>-catalog`
  ExternalSecret and the proxy's `QUERY_FEDERATION_CATALOG_*` env.
- Each role gets its own DuckDB database in every pod, so `memoryLimit` and `threads` are per
  role. Duckling doesn't cap roles: size the pod for the roles the proxy has PATs for (3 x for
  EDS's 3 roles).

**Impact:** roll out in this order:
1. The Go proxy sending `X-Yuki-Catalog-Token` and `X-Yuki-Catalog-Role` (P9). Older Duckling
   images ignore them and keep reading with the PAT.
2. This chart together with a Duckling image that has YU-3372 (terraform-infra `images.duckdb`).
   That Duckling refuses queries without the headers, and older images can't attach the catalog
   with this init SQL.

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
