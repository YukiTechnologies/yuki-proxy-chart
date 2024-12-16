# My Helm Chart

Helm chart for deploying [Yuki Application Proxy].

## Prerequisites

-  Kubernetes 1.16+
-  Helm 3.0+

## Installation

To install the chart with the release name `proxy/proxy`:

| Parameter                            |       Description       | Required |
|:-------------------------------------|:-----------------------:|---------:|
| `app.name`                           |  The name for the app   |       no |
| `app.container.env.REDIS_HOST`       |       Redis host        |      yes |
| `app.container.env.PROXY_HOST`       |   Your Snowflake host   |      yes |
| `app.container.env.COMPANY_GUID`     |    Yuki Company GUID    |      yes |
| `app.container.env.ORG_GUID`         | Yuki Organization GUID  |      yes |
| `app.container.env.ACCOUNT_GUID`     |    Yuki Account GUID    |      yes |
| `ingress.name`                       |      Ingress name       |       no |
| `ingress.className`                  | Your ingress class name |      yes |
| `ingress.annotations.certificateArn` | Your domain certificate |      yes |


```bash
helm install yuki-proxy proxy/proxy -f values.yaml
```


