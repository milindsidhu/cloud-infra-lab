# cloudflared Helm Chart

**Chart version:** `1.0.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Original [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) client chart. Deploys `cloudflared` with tunnel credentials and ingress rules so external traffic can reach private in-cluster services (e.g., Kubernetes API, SSH bastion) via Cloudflare's network.

## Directory Structure

```text
├── Chart.yaml
├── README.md
├── application.yaml
├── templates
│   ├── configmap.yaml
│   └── deployment.yaml
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Templates

- `templates/configmap.yaml` — ConfigMap `cloudflared-config`
- `templates/deployment.yaml` — Deployment `cloudflared` (image: `{{ .Values.image.repository }}:{{ .Values.image.tag }}`)

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

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
