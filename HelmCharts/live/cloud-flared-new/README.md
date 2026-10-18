# cloud-flared-new Helm Chart

**Chart version:** `1.0.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Deploys [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) clients to expose internal Kubernetes services through Cloudflare's edge network without opening public ports. The chart renders a Deployment, tunnel setup Jobs, ConfigMaps, and Secrets for each configured tunnel (k8s API, SSH, ArgoCD, Grafana, MLflow, Minio). It is intended to replace the older `cloudflared` chart.

## Directory Structure

```text
├── Chart.yaml
├── README.md
├── templates
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── job-tunnel-cleanup.yaml
│   ├── job-tunnel-setup-2.yaml
│   └── job-tunnel-setup.yaml
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Templates

- `templates/configmap.yaml` — ConfigMap `configmap`
- `templates/deployment.yaml` — Deployment `deployment` (image: `{{ $.Values.image.repository }}:{{ $.Values.image.tag }}`)
- `templates/job-tunnel-cleanup.yaml` — Job `cloudflared-tunnel-cleanup` (image: `alpine:3.19`)
- `templates/job-tunnel-setup-2.yaml` — Job `cloudflared-tunnel-setup` (image: `alpine:3.19`)
- `templates/job-tunnel-setup.yaml` — Job `job-tunnel-setup` (image: `alpine:3.19`)

## Usage

Render the chart locally:

```bash
helm template cloud-flared-new . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install cloud-flared-new . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
