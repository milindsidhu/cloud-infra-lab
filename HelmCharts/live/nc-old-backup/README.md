# namespace-rbac Helm Chart

**Chart version:** `0.1.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Legacy backup of the original namespace-controller implementation. Kept for reference only; not intended for active deployments.

## Directory Structure

```text
├── Chart.yaml
├── README.md
├── output.yaml
├── templates
│   ├── JobPatchSecret.yaml
│   ├── dockerSecretReplicator.yaml
│   ├── namespace-serviceAccount.yaml
│   ├── permissions.yaml
│   ├── postsyncJob.yaml
│   ├── preDeleteFinalizerPatch.yaml
│   ├── readsecretClusterRole.yaml
│   ├── rep2.yaml
│   ├── role.yaml
│   └── roleBinding.yaml
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Templates

- `templates/JobPatchSecret.yaml` — Secret `secret-patcher`
- `templates/dockerSecretReplicator.yaml` — Secret `dockerSecretReplicator`
- `templates/namespace-serviceAccount.yaml` — ServiceAccount `sa-`
- `templates/permissions.yaml` — Namespace `sa-`
- `templates/postsyncJob.yaml` — Job `postsyncJob` (image: `bitnami/kubectl:latest`)
- `templates/preDeleteFinalizerPatch.yaml` — Job `cleanup-kopf-finalizer-` (image: `bitnami/kubectl:latest`)
- `templates/readsecretClusterRole.yaml` — Secret `read-secret-clusterrole`
- `templates/rep2.yaml` — Resource `rep2` (image: `{{ printf`)
- `templates/role.yaml` — RBAC resource `role-`
- `templates/roleBinding.yaml` — RBAC resource `sa-`

## Usage

Render the chart locally:

```bash
helm template namespace-rbac . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install namespace-rbac . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
