# external-secrets-wrapper Helm Chart

**Chart version:** `0.1.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Wrapper chart for the [External Secrets Operator (ESO)](https://external-secrets.io). Synchronizes secrets from external secret-management systems (AWS Secrets Manager, Vault, etc.) into Kubernetes `Secret` objects using `ClusterSecretStore` and `ExternalSecret` resources.

## Directory Structure

```text
├── Chart.lock
├── Chart.yaml
├── README.md
├── charts
│   └── external-secrets-2.6.0.tgz
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Dependencies

- `external-secrets` version `2.6.0` from `https://charts.external-secrets.io`

## Usage

Render the chart locally:

```bash
helm template external-secrets-wrapper . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install external-secrets-wrapper . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
