# Warp
This repository contains the Helm chart used to deploy the Yuki Proxy service in Kubernetes.

## Related repositories
- terraform-infra: Holds Argo CD configurations (ApplicationSet `proxies-appset`) that deploy one proxy per customer/namespace. It pins the chart using `proxyChartVersion` and provides per-proxy values (including enabling ingress).
- ClientProxy/yuki-proxy: Application source code and runtime routing logic for the proxy. Container images are published to AWS ECR and referenced by `terraform-infra`.

## Deployment flow
1. Change chart code here and bump `Chart.yaml` version.
2. Merge to main; CI publishes the new chart to GitHub Pages (yuki-proxy-chart repo index).
3. Update `proxyChartVersion` in `terraform-infra` to the new version; Argo CD syncs and rolls out.

## Ingress/ALB architecture (Feb 17, 2026)
- Proxies share a single ALB per region using AWS Load Balancer Controller ingress groups.
- Chart now supports host-based routing via `spec.rules[].host`.
- Default host: `{namespace}.yukicomputing.com` (override with `ingress.host` if needed).
- Region-specific settings (cert, tags) are configured in `terraform-infra` values.

### Key values
- `ingress.annotations["alb.ingress.kubernetes.io/group.name"]`: Group name to place multiple ingresses on one ALB (e.g., `yuki-proxies-us-east-1`).
- `ingress.host`: Optional explicit hostname; defaults to `{namespace}.yukicomputing.com`.

## Common tasks
- Add a new proxy: create a values file in `terraform-infra` under `apps/values/proxy/<env>/<region>/<namespace>/values.yaml` and set `ingress.enabled: true`.
- Migrate routing: adjust `ingress.host` per proxy if a non-default domain is required.

## Self-hosted (on‑prem) deployments
If customers deploy the proxy in their own cluster (non‑EKS), the chart still works. Key notes:
- Do not set AWS ALB annotations. Use the ingress class available in the customer cluster (e.g., `nginx`, `traefik`, `istio`).
- You must set a valid hostname via `ingress.host` for the customer’s domain. The default `{namespace}.yukicomputing.com` is only for Yuki‑managed environments.
- TLS: most non‑ALB ingress controllers terminate TLS via `spec.tls`. The chart currently focuses on ALB annotations; if you need first‑class TLS fields (e.g., `ingress.tls`), open an issue/PR and we’ll add it.
- DNS: if the cluster runs external‑dns, it will read `spec.rules[].host`; otherwise, create the DNS record pointing to the customer’s ingress/load balancer.

Example values for NGINX ingress:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  host: proxy.customer.example.com
```
