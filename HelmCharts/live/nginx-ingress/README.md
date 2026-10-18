# nginx-ingress Helm Chart

**Chart version:** `0.1.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Wrapper chart for the [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/). Provides HTTP/HTTPS ingress routing, TLS termination, and integration with cert-manager and external-dns.

## Directory Structure

```text
├── .helmignore
├── Chart.lock
├── Chart.yaml
├── README.md
├── charts
│   └── nginx-21.0.6.tgz
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Dependencies

- `nginx` version `21.0.6` from `https://charts.bitnami.com/bitnami`

## Usage

Render the chart locally:

```bash
helm template nginx-ingress . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install nginx-ingress . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
