# Namespace Controller

A Helm chart that standardizes Kubernetes namespace provisioning and namespace-scoped RBAC.

The chart automates the creation of namespaces, ServiceAccounts, Roles, RoleBindings, and optional image pull secret replication while remaining compatible with policy enforcement tools such as Kyverno.

It is intended for platform teams managing multiple application namespaces with consistent security, governance, and access control.

---

## Features

- Creates Kubernetes namespaces
- Automatically labels namespaces for policy enforcement
- Creates namespace-scoped ServiceAccounts
- Creates least-privilege Roles and RoleBindings
- Supports reusable RBAC rule sets
- Automatically patches a shared image pull secret for replication using mittwald Kubernetes Replicator
- Optional GitOps provider annotations (ArgoCD by default, extensible to other providers)
- Helm-native and GitOps friendly

---

## Architecture

The chart manages two categories of namespaces.

### 1. Regulated Namespaces (No ServiceAccount)

These namespaces receive:

- Namespace
- Standard labels
- Policy enforcement labels

No ServiceAccount, Role, or RoleBinding is created because these namespaces are expected to host cluster-scoped operators that manage their own RBAC.

Typical examples include:

- ingress-nginx
- cert-manager
- external-secrets
- kyverno
- istio-system
- actions-runner-system

These namespaces remain fully governed by policy enforcement.

---

### 2. Application Namespaces

Application namespaces receive:

- Namespace
- Labels
- ServiceAccount
- Namespace-scoped Role
- RoleBinding

Example namespaces:

- mlflow
- cloudflared

Additional namespaces can be added through `values.yaml`.

---

## Namespace Labels

Every managed namespace receives the following labels:

```yaml
app.kubernetes.io/managed-by: nc
secrets.io/managed: "true"
policy-scope: enforced
```

These labels are intended for integration with admission controllers such as Kyverno.

---

## Secret Replication

The chart can optionally create a Kubernetes Job that patches a shared image pull secret with replication annotations for all managed namespaces.

The generated annotation resembles:

```
replicator.v1.mittwald.de/replicate-to=<all managed namespaces>
```

When using the mittwald Kubernetes Replicator, the secret is automatically replicated into every managed namespace.

---

## GitOps Support

The chart is Helm-native and does **not** require any GitOps platform.

GitOps-specific annotations are optional and configurable through `values.yaml`.

Supported deployment methods include:

- Helm CLI
- ArgoCD
- FluxCD
- Helmfile
- Terraform Helm Provider
- Rancher Fleet

Additional GitOps providers can be supported by defining their annotations in `values.yaml` without modifying the chart templates.

---

## Prerequisites

| Component | Required | Notes |
|-----------|----------|-------|
| Kubernetes | >=1.25 | Yes |
| Helm | >=3.12 | Yes |
| mittwald Kubernetes Replicator | Optional | Required only for automatic secret replication |
| Kyverno | Optional | Recommended for policy enforcement |
| GitOps Platform | Optional | Only required if GitOps-specific annotations are desired |

---

## Installation

Install directly from the chart:

```bash
helm install namespace-controller .
```

Or from a Helm repository:

```bash
helm repo add namespace-controller https://<repo>

helm install namespace-controller namespace-controller/namespace-controller
```

---

## Configuration

### regulatedNoSANamespaces

Namespaces that should be created **without** a ServiceAccount or namespace-scoped RBAC.

Example:

```yaml
regulatedNoSANamespaces:
  - ingress-nginx
  - cert-manager
```

---

### appNamespaces

Application namespaces that receive namespace-scoped RBAC.

Example:

```yaml
appNamespaces:
  mlflow:
    roleRules: *standardApp

  cloudflared:
    roleRules: *standardApp
```

---

### roleRuleSets

Reusable Role definitions.

Example:

```yaml
roleRuleSets:
  standardApp:
    ...
```

---

### createPatchJob

Enable or disable the registry secret patch job.

```yaml
createPatchJob:
  enabled: true
```

---

### gitops

Configure optional GitOps provider annotations.

Example:

```yaml
gitops:
  provider: argocd
```

Additional providers can be defined under:

```yaml
gitops:
  providers:
    argocd:
      ...
```

---

## Security Model

The chart intentionally creates only namespace-scoped RBAC resources.

It **does not** create:

- ClusterRoles
- ClusterRoleBindings

Cluster-scoped operators are expected to manage their own RBAC independently.

This approach follows the principle of least privilege.

---

## Compatibility

Tested with:

- Kubernetes 1.27+
- Helm 3.x
- Kyverno
- External Secrets Operator
- ingress-nginx
- cert-manager
- mittwald Kubernetes Replicator
- ArgoCD
- FluxCD

---

## Example

```bash
helm install namespace-controller .
```

This deploys:

- Managed namespaces
- Namespace labels
- ServiceAccounts
- Roles
- RoleBindings
- Optional registry secret patch Job

---

## Contributing

Contributions, feature requests, bug reports, and pull requests are welcome.

If you'd like to support additional GitOps providers or improve the RBAC templates, feel free to open an issue or submit a pull request.

---

## License

Licensed under the Apache License 2.0.