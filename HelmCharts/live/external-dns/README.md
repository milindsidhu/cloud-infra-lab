# external-dns Helm Chart

**Chart version:** `0.1.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Wrapper chart for the [ExternalDNS](https://kubernetes-sigs.github.io/external-dns/) operator. ExternalDNS synchronizes exposed Kubernetes Services and Ingresses with DNS providers such as Cloudflare. This chart deploys the Bitnami-packaged `external-dns` controller and passes provider configuration through `values.yaml`.

## Directory Structure

```text
├── .helmignore
├── Chart.lock
├── Chart.yaml
├── README.md
├── charts
│   └── external-dns-8.9.2.tgz
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Dependencies

- `external-dns` version `8.9.2` from `https://charts.bitnami.com/bitnami`

## Usage

Render the chart locally:

```bash
helm template external-dns . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install external-dns . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
