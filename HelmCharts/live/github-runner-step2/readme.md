# GitHub Actions Runner Deployment with HorizontalRunnerAutoscaler

Kubernetes manifests for deploying repository-scoped GitHub Actions self-hosted runners using **Actions Runner Controller (ARC)** and **HorizontalRunnerAutoscaler (HRA)**.

The runners automatically scale based on the number of queued and in-progress GitHub Actions workflow runs.

## Features

* Repository-scoped GitHub Actions runners
* HorizontalRunnerAutoscaler (HRA)
* Custom runner image with KICS pre-installed
* Compatible with the official `summerwind/actions-runner:latest` image
* Private registry support
* Configurable resources, node selectors, and tolerations

## Prerequisites

* Kubernetes cluster
* Actions Runner Controller (ARC)
* GitHub Personal Access Token or GitHub App configured with ARC
* Image pull secret (only if using a private registry)

## Runner Image

This deployment uses:

```yaml
image: milindsidhu/actions-runner-kics:v2.1.20
```

The image is based on the official `summerwind/actions-runner:latest` image with **KICS (Keeping Infrastructure as Code Secure)** pre-installed for personal use, eliminating the need to install KICS during every workflow run.

If KICS is not required, simply replace the image with:

```yaml
image: summerwind/actions-runner:latest
```

## HorizontalRunnerAutoscaler

Current configuration:

* **Minimum runners:** 1
* **Maximum runners:** 5
* **Metric:** Total queued and in-progress GitHub Actions workflow runs

Adjust these values in the `HorizontalRunnerAutoscaler` manifest to suit your workload.

## Security

The runner container is configured with `privileged: true` and the `SYS_ADMIN` capability for workflows that require elevated privileges (for example, Docker-based builds). Reduce these permissions if they are not needed.
