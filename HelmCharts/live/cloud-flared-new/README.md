# cloudflared Helm Chart

**Chart version:** `1.0.0`  
**Environment:** `HelmCharts/live/cloud-flared-new/`

## What This Chart Does

This is the **refactored** [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) client chart. It deploys the `cloudflared` daemon to expose multiple internal Kubernetes services through Cloudflare's edge network, without opening public ingress ports on the cluster.

The chart is designed as a more flexible replacement for the older `HelmCharts/live/cloudflared/` chart. It supports several tunnels (k8s API, SSH, ArgoCD, Grafana, MLflow, Minio) via separate ConfigMaps and credentials Secrets, and includes Helm hooks that create and clean up Cloudflare tunnels automatically.

## Directory Structure

```text
├── Chart.yaml
├── README.md
├── templates
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── job-tunnel-cleanup.yaml
│   ├── job-tunnel-setup-2.yaml
│   └── job-tunnel-setup.yaml
└── values.yaml
```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Templates

- `templates/configmap.yaml` — ConfigMap `configmap`
- `templates/deployment.yaml` — Deployment `deployment` (image: `{{ $.Values.image.repository }}:{{ $.Values.image.tag }}`)
- `templates/job-tunnel-setup.yaml` — PreSync Helm hook Job that creates Cloudflare tunnels via the cloudflared CLI
- `templates/job-tunnel-setup-2.yaml` — Additional tunnel setup helper Job
- `templates/job-tunnel-cleanup.yaml` — Pre-delete Helm hook Job that removes Cloudflare tunnels on uninstall

## Usage

Render the chart locally:

```bash
helm template cloudflared . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install cloudflared . -f values.yaml -n <NAMESPACE> --create-namespace
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<SSH_HOST>`, `<NAMESPACE>`, etc., with real values before deploying.
- Each tunnel uses its own credential Secret and ConfigMap so that multiple hostnames can be managed independently.
