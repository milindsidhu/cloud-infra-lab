# splunk-lab Helm Chart

**Chart version:** `1.0.0`  
**Environment:** `HelmCharts/dev/`

## What This Chart Does

Deploys a self-contained Splunk lab stack for log-analytics experimentation. Components include:

- **Splunk Enterprise** (single instance with PVC),
- a **target app** that emits logs/metrics,
- a **load generator** to create traffic spikes,
- **Fluent Bit** DaemonSet to forward logs to Splunk HEC,
- and an optional legacy Splunk forwarder.

Useful for learning Splunk SPL, dashboards, and alerting without external dependencies.

## Directory Structure

```text
├── Chart.yaml
├── README.md
├── templates
│   ├── _helpers.tpl
│   ├── control-panel-configmap.yaml
│   ├── control-panel-deployment.yaml
│   ├── control-panel-service.yaml
│   ├── fluent-bit-configmap.yaml
│   ├── fluent-bit-daemonset.yaml
│   ├── fluent-bit-rbac.yaml
│   ├── load-generator-deployment.yaml
│   ├── load-generator-service.yaml
│   ├── splunk-enterprise-deployment.yaml
│   ├── splunk-enterprise-pvc.yaml
│   ├── splunk-enterprise-service.yaml
│   ├── splunk-forwarder-configmap.yaml
│   ├── splunk-forwarder-daemonset.yaml
│   ├── splunk-forwarder-rbac.yaml
│   ├── target-app-deployment.yaml
│   └── target-app-service.yaml
└── values.yaml

```

## Key Files

- **`Chart.yaml`** — Helm chart metadata (name, version, dependencies).
- **`values.yaml`** — Default configuration. Review and override before production use.
- **`.helmignore`** — Patterns for files to exclude from the packaged chart.

## Templates

- `templates/control-panel-configmap.yaml` — ConfigMap `control-panel-configmap`
- `templates/control-panel-deployment.yaml` — Deployment `control-panel-deployment` (image: `{{ include`)
- `templates/control-panel-service.yaml` — Service `control-panel-service`
- `templates/fluent-bit-configmap.yaml` — ConfigMap `fluent-bit-configmap`
- `templates/fluent-bit-daemonset.yaml` — DaemonSet `http-metrics` (image: `cr.fluentbit.io/fluent/fluent-bit:3.2`)
- `templates/fluent-bit-rbac.yaml` — ServiceAccount `fluent-bit-rbac`
- `templates/load-generator-deployment.yaml` — Deployment `load-generator-deployment` (image: `{{ include`)
- `templates/load-generator-service.yaml` — Service `load-generator-service`
- `templates/splunk-enterprise-deployment.yaml` — Deployment `splunk-enterprise-deployment` (image: `splunk/splunk:{{ .Values.splunkEnterprise.image.tag }}`)
- `templates/splunk-enterprise-pvc.yaml` — PersistentVolumeClaim `splunk-enterprise-pvc`
- `templates/splunk-enterprise-service.yaml` — Service `splunk-enterprise-service`
- `templates/splunk-forwarder-configmap.yaml` — ConfigMap `splunk-forwarder-configmap`
- `templates/splunk-forwarder-daemonset.yaml` — DaemonSet `splunk-forwarder-daemonset` (image: `{{ .Values.splunkForwarder.image.repository }}:{{ .Values.splunkForwarder.image.tag }}`)
- `templates/splunk-forwarder-rbac.yaml` — ServiceAccount `splunk-forwarder-rbac`
- `templates/target-app-deployment.yaml` — Deployment `target-app-deployment` (image: `{{ include`)
- `templates/target-app-service.yaml` — Service `target-app-service`

## Usage

Render the chart locally:

```bash
helm template splunk-lab . -f values.yaml
```

Install or upgrade in a cluster:

```bash
helm upgrade --install splunk-lab . -f values.yaml -n <NAMESPACE> --create-namespace
```

For wrapper charts that ship vendored `.tgz` dependencies, unpack them first if needed:

```bash
helm dependency update
```

## Notes

- Replace placeholder values such as `<DOMAIN>`, `<CLOUDFLARE_TUNNEL_ID>`, `<NAMESPACE>`, etc., with real values before deploying.
