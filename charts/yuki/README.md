# Yuki Proxy Helm Chart

Helm chart for deploying [Yuki Application Proxy].

## Prerequisites

-  Kubernetes 1.16+
-  Helm 3.0+

## Installation

To install the chart with the release name `yuki/proxy`:

| Parameter                             |         Description          | Required |      Default       |
|:--------------------------------------|:----------------------------:|---------:|:------------------:|
| `app.name`                            |     The name for the app     |       no |     yuki-proxy     |
| `app.namespace`                       |  The namespace for the app   |       no |     yuki-proxy     |
| `app.container.env.REDIS_HOST`        |          Redis host          |      yes |        none        |
| `app.container.env.PROXY_HOST`        |     Your Snowflake host      |      yes |        none        |
| `app.container.env.COMPANY_GUID`      |      Yuki Company GUID       |      yes |        none        |
| `app.container.env.ORG_GUID`          |    Yuki Organization GUID    |      yes |        none        |
| `app.container.env.ACCOUNT_GUID`      |      Yuki Account GUID       |      yes |        none        |
| `ingress.enabled`                     |        Ingress config        |       no |        true        |
| `ingress.name`                        |         Ingress name         |       no | yuki-proxy-ingress |
| `ingress.className`                   |   Your ingress class name    |      yes |        none        |
| `ingress.annotations.certificateArn`  |   Your domain certificate    |      yes |        none        |
| `ingress.annotations.route53Domain`   |   Your domain certificate    |      yes |        none        |
| `deployment.spec.tolerations.enabled` | Deployment toleration config |       no |       false        |
| `deployment.spec.affinity.enabled`    |  Deployment affinity config  |       no |       false        |
| `hpa.enabled`                         |      Service HPA config      |       no |        true        |
| `service_account.enabled`             |  Service account for proxy   |       no |       false        |
| `service_account.role_arn`            |   Service account role arn   |       no |         ""         |


```bash
helm repo add yuki https://yukitechnologies.github.io/yuki-proxy-chart
helm install yuki-proxy yuki/proxy -f values.yaml
```


