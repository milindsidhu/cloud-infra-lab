# namespace-controller Helm Chart

**Chart version:** `0.2.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Centralized namespace and RBAC governance chart. It creates regulated namespaces, application namespaces, dedicated ServiceAccounts, namespaced Roles/RoleBindings, and narrowly-scoped ClusterRoles/ClusterRoleBindings for CRD access. It also creates a central pull-secret namespace (`registry-secrets`) and runs a PostSync Job that annotates the central docker-registry Secret so the mittwald replicator fans it out to all managed namespaces.

The chart vendors `kubernetes-replicator` (mittwald) as a dependency, so the replicator is installed together with the namespace controller instead of requiring a separate ArgoCD Application. It is deployed into the dedicated `mittwald-replicator` namespace (created by this chart) via `namespaceOverride`.

The Secret itself can be created by the chart (set `centralSecretNamespace.createSecret: true`) or supplied manually / via External Secrets (set `createSecret: false`).

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

- `templates/central-namespace.yaml` — Creates the central `registry-secrets` namespace
- `templates/patch-job.yaml` — PostSync Job that annotates the central Secret for mittwald-replicator fan-out
- `templates/permissions.yaml` — Creates namespaces, ServiceAccounts, Roles, RoleBindings, ClusterRoles, and ClusterRoleBindings based on `values.yaml` categories
- `templates/secret.yaml` — Creates the central docker-registry Secret in `registry-secrets`

## Usage

Render the chart locally:

```bash
helm template namespace-controller . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install namespace-controller . -f values.yaml -n <NAMESPACE> --create-namespace
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
