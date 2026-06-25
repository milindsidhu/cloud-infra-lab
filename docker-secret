# Creating a Docker Registry Secret in Kubernetes

A `docker-registry` secret allows Kubernetes to authenticate with a container registry when pulling private images.

---

## Prerequisites

- `kubectl` configured and connected to your cluster
- A Docker Hub account with a Personal Access Token (PAT)

> **Note:** Using a PAT instead of your password is recommended — you can scope and revoke it independently.

---

## Create the Secret

```bash
kubectl create secret docker-registry <secret-name> \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<username> \
  --docker-password=<docker_pat> \
  --docker-email=<email> \
  --namespace=<namespace>
```

### For other registries

| Registry | `--docker-server` value |
|---|---|
| Docker Hub | `https://index.docker.io/v1/` |
| GitHub Container Registry | `ghcr.io` |
| Google Artifact Registry | `<region>-docker.pkg.dev` |
| AWS ECR | `<account>.dkr.ecr.<region>.amazonaws.com` |
| Azure Container Registry | `<registry>.azurecr.io` |

---

## Use the Secret in a Pod or Deployment

Reference the secret under `imagePullSecrets`:

```yaml
spec:
  imagePullSecrets:
    - name: <secret-name>
  containers:
    - name: my-app
      image: <username>/<image>:<tag>
```

---

## Verify the Secret

```bash
kubectl get secret <secret-name> -n <namespace>
```

To inspect the contents:

```bash
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.\.dockerconfigjson}' | base64 --decode
```

---

## Replicate Across Namespaces

If multiple namespaces need the same secret, use the [mittwald kubernetes-replicator](https://github.com/mittwald/kubernetes-replicator) or External Secrets Operator rather than recreating it manually.

Add this annotation to auto-replicate:

```yaml
metadata:
  annotations:
    replicator.v1.mittwald.de/replicate-to: "<namespace1>,<namespace2>"
```