# My Helm Chart

Helm chart for deploying [Yuki Application Proxy].

## Prerequisites

-  Kubernetes 1.16+
-  Helm 3.0+

## Installation

To install the chart with the release name `proxy/yuki-proxy`:

| Parameter     |   Description   | Default |
|:--------------|:---------------:|--------:|
| `image`       | some wordy text |   $1600 |
| `port`        |    centered     |     $12 |
| zebra stripes |    are neat     |      $1 |


```bash
helm install yuki-proxy proxy/yuki-proxy -f values.yaml
```


