# my-runner-ctrl Helm Chart

**Chart version:** `0.1.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Wrapper chart for the [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller). ARC provisions self-hosted GitHub Actions runners as Kubernetes pods on demand, allowing CI/CD jobs to run inside the cluster with custom images and resources.

## Directory Structure

```text
├── .helmignore
├── Chart.lock
├── Chart.yaml
├── README.md
├── charts
│   └── actions-runner-controller-0.23.7.tgz
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Dependencies

- `actions-runner-controller` version `0.23.7` from `https://actions-runner-controller.github.io/actions-runner-controller`

## Usage

Render the chart locally:

```bash
helm template my-runner-ctrl . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install my-runner-ctrl . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
