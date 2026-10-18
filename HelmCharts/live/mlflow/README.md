# mlflow Helm Chart

**Chart version:** `0.1.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Deploys an [MLflow](https://mlflow.org) tracking server for machine-learning experiment tracking, model registry, and artifact management.

## Directory Structure

```text
├── Chart.yaml
├── README.md
├── templates
│   └── mlflow.yaml
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Dependencies

- `minio` version `5.4.0` from `https://charts.min.io/`
- `postgresql` version `18.7.5` from `https://charts.bitnami.com/bitnami`

## Templates

- `templates/mlflow.yaml` — Deployment `mlflow` (image: `ghcr.io/mlflow/mlflow:v2.13.0`)

## Usage

Render the chart locally:

```bash
helm template mlflow . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install mlflow . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
