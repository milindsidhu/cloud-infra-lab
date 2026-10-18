# splunk-siem-explorer Helm Chart

**Chart version:** `1.0.0`  
**Environment:** `HelmCharts/dev/`

## What This Chart Does

Deploys a **Splunk SIEM explorer** demo application. It consists of a backend API, a frontend UI, and a PostgreSQL database used to store SIEM use-case metadata. Intended for exploring SIEM data correlation, incident workflows, and frontend-to-backend integration.

## Directory Structure

```text
├── Chart.yaml
├── README.md
├── templates
│   ├── _helpers.tpl
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-configmap.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── ingress.yaml
│   ├── postgres-deployment.yaml
│   ├── postgres-pvc.yaml
│   ├── postgres-service.yaml
│   └── secret.yaml
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Templates

- `templates/backend-deployment.yaml` — Deployment `backend-deployment` (image: `busybox:1.38.0`)
- `templates/backend-service.yaml` — Service `backend-service`
- `templates/frontend-configmap.yaml` — ConfigMap `frontend-configmap`
- `templates/frontend-deployment.yaml` — Deployment `frontend-deployment` (image: `{{ include`)
- `templates/frontend-service.yaml` — Service `frontend-service`
- `templates/ingress.yaml` — Ingress `ingress`
- `templates/postgres-deployment.yaml` — Deployment `postgres-deployment` (image: `{{ include`)
- `templates/postgres-pvc.yaml` — PersistentVolumeClaim `postgres-pvc`
- `templates/postgres-service.yaml` — Service `postgres-service`
- `templates/secret.yaml` — Secret `secret`

## Usage

Render the chart locally:

```bash
helm template splunk-siem-explorer . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install splunk-siem-explorer . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
