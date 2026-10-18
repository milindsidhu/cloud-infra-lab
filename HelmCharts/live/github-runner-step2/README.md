# github-runner-step2

**Environment:** `HelmCharts/live/github-runner-step2/`

## What This Directory Does

These manifests extend the [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller) deployment from `HelmCharts/live/github-action-runner-controller/`. They define the actual runner pool and autoscaling behavior, while the controller chart installs the operator that manages them.

- **`RunnerDeployment`** — Declares a pool of self-hosted GitHub Actions runners for a specific repository.
- **`HorizontalRunnerAutoscaler`** — Automatically scales the `RunnerDeployment` between `minReplicas` and `maxReplicas` based on the number of queued and in-progress workflow runs.

## Files

- `runnerDeployment.yaml` — `RunnerDeployment` resource named `repo-runners` in namespace `actions-runner-system`. It targets the `milindsidhu/Projects` repository, uses a custom runner image, pulls it with `my-registry-secret`, runs on the `linux-master` control-plane node, and grants `SYS_ADMIN` privileges for Docker-in-Docker or elevated CI workloads.
- `horizontalRunnerAutoscaler.yaml` — `HorizontalRunnerAutoscaler` resource named `repo-runners-autoscaler`. It scales the `repo-runners` RunnerDeployment from 1 to 5 replicas based on total queued and in-progress workflow runs.

## Usage

Install the controller first from `../github-action-runner-controller/`, then apply these manifests:

```bash
kubectl apply -f runnerDeployment.yaml -f horizontalRunnerAutoscaler.yaml
```

## Notes

- The runner pod is privileged (`privileged: true`) and adds `SYS_ADMIN`. Only use this configuration in a trusted, isolated CI environment.
- Update `repository`, `image`, `nodeSelector`, and `tolerations` to match your target repository and cluster topology.
