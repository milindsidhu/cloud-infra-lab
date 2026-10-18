# kyvernoPolicies

**Environment:** `HelmCharts/live/kyvernoPolicies/`

## What This Directory Does

This directory contains [Kyverno](https://kyverno.io) `ClusterPolicy` manifests for governance and hardening. Kyverno is a Kubernetes-native policy engine that validates, mutates, and generates resources using declarative YAML rules. Policies here target namespaces labeled `policy-scope=enforced` and the `actions-runner-system` namespace used by ARC.

## Files

### Validation policies (enforced)

- **`labels.yaml`** — `require-labels` policy. Ensures every Pod in namespaces labeled `policy-scope=enforced` has `app` and `env` labels.
- **`resource-limit.yaml`** — `require-resource-limits` policy. Ensures every container in namespaces labeled `policy-scope=enforced` defines CPU and memory limits.
- **`service-account.yaml`** — `require-namespace-service-account` policy. Ensures Pods in app namespaces use the per-namespace ServiceAccount `sa-<namespace>` created by the namespace-controller. System/operators namespaces are excluded.

### Mutation policies (commented out)

These policies are currently disabled. When enabled, they mutate GitHub Actions runner pods in `actions-runner-system` to inject labels, resources, or init-container resources automatically.

- **`labelinject-ghub-arc.yaml`** — Injects `app: gha-runner` and `env: prod` labels into ARC runner Pods.
- **`resourceInject-ghub-arc.yaml`** — Injects CPU/memory requests and limits into all containers of ARC runner Pods.
- **`ghub-arc-mutate-all-container.yaml`** — Injects CPU/memory requests and limits into initContainers of ARC runner Pods.

## Usage

Install the Kyverno controller first, then apply the policies:

```bash
kubectl apply -f .
```

## Notes

- Validation policies exclude system namespaces (`kube-system`, `argocd`, `kyverno`, `cert-manager`, etc.) and selected operator namespaces.
- The mutation policies rely on the exact namespace name `actions-runner-system`.
