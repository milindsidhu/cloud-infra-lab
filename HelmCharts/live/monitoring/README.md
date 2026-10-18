# monitoring Helm Chart

**Chart version:** `1.0.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Wrapper chart for the [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack). This deploys Prometheus for metrics collection and storage, Grafana for visualization dashboards, and Alertmanager for alert routing. The chart also creates an ExternalSecret to inject the Grafana admin password from an external secrets manager.

## Directory Structure

```text
├── Chart.yaml
├── README.md
├── templates
│   └── external-secret-grafana.yaml
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Dependencies

- `kube-prometheus-stack` version `65.1.1` from `https://prometheus-community.github.io/helm-charts`

## Templates

- `templates/external-secret-grafana.yaml` — Secret `grafana-admin-secret`

## Usage

Render the chart locally:

```bash
helm template monitoring . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install monitoring . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
