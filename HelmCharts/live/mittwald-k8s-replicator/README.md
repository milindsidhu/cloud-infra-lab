# mittwald-k8s-replicator Helm Chart

**Chart version:** `0.1.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Wrapper chart for [mittwald/kubernetes-replicator](https://github.com/mittwald/kubernetes-replicator). Replicates Secrets and ConfigMaps from a source namespace to other namespaces based on annotations.

## Directory Structure

```text
├── .helmignore
├── Chart.lock
├── Chart.yaml
├── README.md
├── charts
│   └── kubernetes-replicator-2.11.1.tgz
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Dependencies

- `kubernetes-replicator` version `2.11.1` from `https://helm.mittwald.de`

## Usage

Render the chart locally:

```bash
helm template mittwald-k8s-replicator . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install mittwald-k8s-replicator . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
