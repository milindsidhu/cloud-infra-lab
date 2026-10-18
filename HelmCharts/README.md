# HelmCharts

This directory contains Helm charts organized by environment.

## Layout

```text
HelmCharts/
├── dev/        # Development / experimental charts
└── live/       # Production-ready / active charts
```

## Environments

### `dev/`

Charts used for local development, experimentation, or non-production workloads.

| Chart | Purpose |
|---|---|
| `backstage` | Backstage developer portal deployment |
| `langapp` | langApp FastAPI runner (dev values) |
| `splunk-lab` | Splunk lab stack (Splunk Enterprise + Fluent Bit + forwarders) |
| `splunk-siem-explorer` | Splunk SIEM explorer demo app |

### `live/`

Charts deployed to shared / production clusters.

| Chart | Purpose |
|---|---|
| `cloud-flared-new` | Cloudflare tunnel client (refactored version) |
| `cloudflared` | Cloudflare tunnel client (original version) |
| `external-dns` | External DNS operator (Helm dependency) |
| `external-secrets` | External Secrets Operator (ESO) |
| `github-action-runner-controller` | GitHub Actions Runner Controller (ARC) |
| `github-runner-step2` | Additional runner deployment manifests |
| `kyvernoPolicies` | Kyverno mutation/validation policies |
| `langapp` | langApp FastAPI runner (live values) |
| `longhorn` | Longhorn distributed block storage |
| `metallb` | MetalLB load-balancer |
| `mittwald-k8s-replicator` | kubernetes-replicator for cross-namespace secrets |
| `mlflow` | MLflow tracking server |
| `monitoring` | Monitoring stack ExternalSecret for Grafana |
| `namespaceController` | Central namespace, RBAC, and pull-secret management |
| `nc-old-backup` | Old namespace-controller backup (kept for reference) |
| `nginx-ingress` | NGINX Ingress Controller |

## Conventions

- Each chart has its own `Chart.yaml`, `values.yaml`, and `templates/` directory.
- `README.md` inside each chart explains its structure and templates.
- `out.yaml` files are rendered manifests kept for quick inspection.
- `charts/` directories contain vendored Helm dependencies.
