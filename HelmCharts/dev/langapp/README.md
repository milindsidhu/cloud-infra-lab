# lang-app Helm Chart

**Chart version:** `0.1.0`  
**Environment:** `HelmCharts/dev/`

## What This Chart Does

Deploys the **langApp** interactive code-execution service. The FastAPI backend exposes a browser UI and REST/WebSocket endpoints. Users can submit code in Python, Go, or Node.js, which the service runs inside isolated Kubernetes Jobs per request. The chart also deploys a CronJob that cleans up finished Jobs and orphaned ConfigMaps, an Ingress with optional TLS/cert-manager integration, optional external-dns annotations for Cloudflare-tunnel exposure, and a post-install Job that waits for the TLS Secret before the Ingress is created.

## Directory Structure

```text
├── .helmignore
├── Chart.yaml
├── README.md
├── templates
│   ├── cronjob.yaml
│   ├── deployment.yaml
│   ├── ingress.yaml
│   ├── registry-secret.yaml
│   ├── service.yaml
│   └── tls-check-job.yaml
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Templates

- `templates/cronjob.yaml` — CronJob `cronjob` (image: `{{ $.Values.cronjobImage.repository }}`)
- `templates/deployment.yaml` — Deployment `deployment` (image: `{{ $.Values.runnerApi.image }}`)
- `templates/ingress.yaml` — Ingress `ingress`
- `templates/registry-secret.yaml` — Secret `registry-secret`
- `templates/service.yaml` — Service `service`
- `templates/tls-check-job.yaml` — Job `wait-for-tls-secret` (image: `{{ .Values.cronjobImage.repository }}`)

## Usage

Render the chart locally:

```bash
helm template lang-app . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install lang-app . -f values.yaml -n <NAMESPACE> --create-namespace
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
