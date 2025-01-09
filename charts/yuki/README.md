# Yuki Proxy Helm Chart

Helm chart for deploying [Yuki Application Proxy].

## Prerequisites

-  Kubernetes 1.29+
-  Helm 3.0+

## Installation

To install the chart with the release name `yuki/proxy`:

| Parameter                             |         Description          | Required |      Default       |
|:--------------------------------------|:----------------------------:|---------:|:------------------:|
| `app.name`                            |     The name for the app     |       no |     yuki-proxy     |
| `app.container.env.REDIS_HOST`        |          Redis host          |      yes |        none        |
| `app.container.env.PROXY_HOST`        |     Your Snowflake host      |      yes |        none        |
| `ingress.enabled`                     |        Ingress config        |       no |        true        |
| `ingress.name`                        |         Ingress name         |       no | yuki-proxy-ingress |
| `ingress.className`                   |   Your ingress class name    |       no |        none        |
| `ingress.annotations`                 |   Your ingress annotations   |       no |        none        |
| `deployment.spec.tolerations.enabled` | Deployment toleration config |       no |       false        |
| `deployment.spec.affinity.enabled`    |  Deployment affinity config  |       no |       false        |
| `hpa.enabled`                         |      Service HPA config      |       no |        true        |


```bash
helm repo add yuki https://yukitechnologies.github.io/yuki-proxy-chart
helm install yuki-proxy yuki/proxy -f values.yaml
```


