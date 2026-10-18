# Roadmap: Interactive Code Execution in Kubernetes (langApp)

## Current Status

### Phase 1 - Foundation: DONE

- FastAPI backend (`appProject/langApp/fastApi/`)
- Kind-based local Kubernetes cluster
- Helm charts: `dev/langapp`, `live/langapp`, `live/namespaceController`
- Namespace, RBAC, ServiceAccount, Role, RoleBinding for `lang-app`
- CronJob for cleaning up completed/failed jobs and orphaned ConfigMaps

### Phase 2 - Language Job Runner: DONE

- `POST /execute` accepts code + language
- Languages supported: Python, Node.js, Go
- Per-job ConfigMap + Kubernetes Job
- WebSocket streaming of live output
- Job/ConfigMap cleanup when session ends

### Phase 3 - Interactive Shell: DONE

- WebSocket endpoint streams a real shell into the job pod
- Bidirectional stdin/stdout with asyncio thread isolation
- Waits for pod readiness before exec
- Closes exec stream cleanly on disconnect

### Phase 4 - Frontend: DONE (MVP)

- Browser-based code editor + terminal UI
- Language selector, run button, dedicated command input box
- Dark theme, responsive 2-column layout
- Root endpoint serves the UI

### Phase 5 - Security & Platform Hardening: IN PROGRESS

- RBAC includes `pods/exec` and `pods/log`
- Resource limits on helper jobs (`namespaceController` patch job)
- ServiceAccount no longer uses `default` SA for privileged jobs
- Pod Security Standards baseline via namespace labels (`policy-scope=enforced`)

TODO:

- Add NetworkPolicy for `lang-app` namespace
- Run user code containers as non-root with `readOnlyRootFilesystem`
- Add resource quotas / limit ranges for `lang-app`
- Persist session history in DB or volume

## Operational Additions

### Secret Replication Operator (Kopf)

- CRD: `SecretReplicator` (`kopf.dev/v1`)
- Copies secrets across namespaces (e.g. image-pull secrets)
- Lives in `Docker-manifests/secret-replicator/`
- Manifests in `Kubernetes/Kubernetes_manifests/secret-replicator-crd/`

### Centralized Namespace & Pull-Secret Management

- `namespaceController` chart creates namespaces, SAs, Roles, ClusterRoles
- Central pull-secret namespace (`registry-secrets`) with docker-registry Secret
- PostSync Job annotates secret for mittwald-replicator fan-out

## Next Steps

- Move from kind to a real cloud cluster (EKS/GKE) with IRSA/GKE Workload Identity
- Integrate External Secrets Operator (ESO) for AWS Secrets Manager-backed secrets
- Replace basic HTML frontend with React + xterm.js
- Add user authentication / multi-tenancy
- Add metrics and alerting (New Relic / Prometheus)
- Implement GitOps deployment via ArgoCD ApplicationSets
