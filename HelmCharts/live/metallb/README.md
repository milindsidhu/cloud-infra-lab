# metallb Helm Chart

**Chart version:** `0.1.0`  
**Environment:** `HelmCharts/live/`

## What This Chart Does

Wrapper chart for [MetalLB](https://metallb.universe.tf). Exposes Kubernetes `LoadBalancer` services on bare-metal or VM clusters by advertising virtual IPs via L2. Configures `IPAddressPool` and `L2Advertisement` resources.

## Directory Structure

```text
├── .helmignore
├── Chart.lock
├── Chart.yaml
├── README.md
├── charts
│   └── metallb-0.15.2.tgz
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Dependencies

- `metallb` version `0.15.2` from `https://metallb.github.io/metallb`

## Usage

Render the chart locally:

```bash
helm template metallb . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install metallb . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
