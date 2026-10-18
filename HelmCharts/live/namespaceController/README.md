# namespace-controller Helm Chart

**Chart version:** `0.2.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Centralized namespace and RBAC management chart. Creates regulated and application namespaces, dedicated ServiceAccounts, namespaced Roles/RoleBindings, narrowly-scoped ClusterRoles/ClusterRoleBindings for CRD access, and a central pull-secret namespace (`registry-secrets`). A PostSync Job annotates the central docker-registry Secret so the mittwald replicator fans it out to all managed namespaces.

## Directory Structure

```text
├── Chart.yaml
├── README.md
├── templates
│   ├── central-namespace.yaml
│   ├── patch-job.yaml
│   ├── permissions.yaml
│   └── secret.yaml
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Templates

- `templates/central-namespace.yaml` — Namespace `central-namespace`
- `templates/patch-job.yaml` — Job `sa-secret-patcher` (image: `{{ .Values.createPatchJob.image }}`)
- `templates/permissions.yaml` — Namespace `sa-`
- `templates/secret.yaml` — Secret `secret`

## Usage

Render the chart locally:

```bash
helm template namespace-controller . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install namespace-controller . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
