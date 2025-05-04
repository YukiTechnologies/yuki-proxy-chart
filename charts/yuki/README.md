# Yuki Proxy Helm Chart

Helm chart for deploying [Yuki Application Proxy].

## Prerequisites

-  Kubernetes 1.29+
-  Helm 3.0+

## Installation

To install the chart with the release name `yuki/proxy`:

| Parameter                             |         Description          | Required |      Default       |
|:--------------------------------------|:----------------------------:|---------:|:------------------:|
| `app.container.env.PROXY_HOST`        |     Your Snowflake host      |      yes |        none        |
| `app.container.env.REDIS_HOST`        |          Redis host          |      yes |        none        |
| `app.name`                            |     The name for the app     |       no |     yuki-proxy     |
| `hpa.enabled`                         |      Service HPA config      |       no |        true        |
| `ingress.enabled`                     |        Ingress config        |       no |        true        |
| `ingress.name`                        |         Ingress name         |       no | yuki-proxy-ingress |
| `ingress.annotations`                 |   Your ingress annotations   |       no |        none        |
| `ingress.className`                   |   Your ingress class name    |       no |        none        |
| `serviceAccount.roleARN`              | AWS role with secret access  |       no |        none        |
| `serviceAccount.serviceAccountName`   |  The name SA secret access   |       no |    yuki-proxy-sa   |


```bash
helm repo add yuki https://yukitechnologies.github.io/yuki-proxy-chart
helm install yuki-proxy yuki/proxy -f values.yaml
```

## Access to AWS secrets using SA

For k8s services be able to access AWS secrets, two things should happen:
 - Setup following AWS resources ( ./self_hosted_config/SA_for_secret_access/script.sh maybe help ):
    - Make sure that your EKS cluster have OIDC enabled
    - Create AWS policy with tag based access to AWS secrets, e.g. ./self_hosted_config/SA_for_secret_access/secrets-access-policy.json
    - Create AWS role with trust for OIDC of the cluster, e.g ./self_hosted_config/SA_for_secret_access/trust.json
    - Attach policy to role
 - Create SA on a cluster level - managed by this chart if .serviceAccount.serviceAccountName was defined in values.yaml
