# backstage-helm Helm Chart

**Chart version:** `0.1.0`  
**Environment:** `HelmCharts/dev/`

## What This Chart Does

Deploys a [Backstage](https://backstage.io) developer portal backed by PostgreSQL. Backstage is an open platform for building developer portals. It provides a centralized software catalog, technical documentation, and a plugin ecosystem. This chart creates the `backstage` namespace, deploys a PostgreSQL database, and runs the Backstage UI/API container with the required Secrets and Services.

## Directory Structure

```text
├── .helmignore
├── Chart.yaml
├── README.md
├── templates
│   ├── _helpers.tpl
│   ├── deploy-backstage.yaml
│   ├── deploy-postgres.yaml
│   ├── namespace.yaml
│   ├── pvc-postgres.yaml
│   ├── secret-backstage-ghub.yaml
│   ├── secret-postgres.yaml
│   ├── service-backstage.yaml
│   └── service-postgres.yaml
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Templates

- `templates/deploy-backstage.yaml` — Deployment `backstage` (image: `busybox:1.38.0`)
- `templates/deploy-postgres.yaml` — Deployment `backstage-postgres` (image: `{{ .Values.postgres.image }}`)
- `templates/namespace.yaml` — Namespace `namespace`
- `templates/pvc-postgres.yaml` — PersistentVolumeClaim `postgres-storage`
- `templates/secret-backstage-ghub.yaml` — Secret `backstage-ghub-secret`
- `templates/secret-postgres.yaml` — Secret `backstage-db-secret`
- `templates/service-backstage.yaml` — Service `backstage`
- `templates/service-postgres.yaml` — Service `backstage-postgres`

## Usage

Render the chart locally:

```bash
helm template backstage-helm . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install backstage-helm . -f values.yaml -n <NAMESPACE> --create-namespace
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
