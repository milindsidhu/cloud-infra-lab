# longhorn Helm Chart

**Chart version:** `0.1.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Wrapper chart for [Longhorn](https://longhorn.io), a cloud-native distributed block storage system for Kubernetes. Longhorn provides replicated, software-defined persistent volumes with snapshots, backups, and a management UI for stateful workloads running on bare-metal or VM-based clusters.

## Directory Structure

```text
├── .helmignore
├── Chart.lock
├── Chart.yaml
├── README.md
├── charts
│   └── longhorn-1.9.0.tgz
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Dependencies

- `longhorn` version `1.9.0` from `https://charts.longhorn.io`

## Usage

Render the chart locally:

```bash
helm template longhorn . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install longhorn . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
