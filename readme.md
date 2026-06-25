# cloud-infra-lab

A personal infrastructure lab built around a self-hosted Kubernetes cluster — covering multi-cloud provisioning, GitOps-driven deployments, zero-trust networking, secrets management, and end-to-end CI/CD automation.

---

## Terraform — Multi-Cloud IaC

Modular Terraform across AWS, GCP, and Azure covering the full provisioning lifecycle. GCP includes GKE cluster setup with custom node pools, compute VMs with Ansible post-provisioning for nginx reverse proxy configuration, and a dedicated logging module. Azure covers an e-commerce stack with App Service, networking, and service plan modules. AWS uses a remote state backend. All providers are modularised for reuse across environments. A Packer config is included for building a hardened Amazon Linux AMI via GitHub Actions.

---

## Kubernetes — Helm Charts & Manifests

Production-style Helm charts for a self-hosted KubeAdm cluster split across live and dev environments.

The live cluster runs metallb for bare-metal load balancing, nginx ingress controller, Longhorn for distributed block storage, cert-manager for TLS via Let's Encrypt, external-dns for automatic DNS record management, and the mittwald kubernetes-replicator for cross-namespace secret replication. Monitoring is handled by Grafana and Prometheus with credentials sourced from AWS Secrets Manager via ESO. The namespaceController chart manages namespace lifecycle with post-sync jobs and RBAC. Kyverno admission policies enforce resource limits, label injection, and service account rules across the cluster. Self-hosted GitHub Actions runners are managed via the Actions Runner Controller with horizontal autoscaling. Cloudflare Tunnel provides zero-trust ingress without exposing any cluster ports.

Dev/lab charts include a full Backstage internal developer portal with Postgres, a Splunk log forwarding pipeline using Fluent Bit as a DaemonSet, a complete SIEM explorer stack with backend API, frontend, and Postgres, and an MLflow experiment tracking deployment.

Raw Kubernetes manifests cover ArgoCD non-HA install, cert-manager ClusterIssuers, Cloudflare Tunnel deployment, MetalLB L2 advertisement, nginx app, and secret replication configs.

---

## GitOps — ArgoCD

The entire cluster state is managed declaratively via ArgoCD. An ApplicationSet bootstraps the External Secrets Operator alongside its ClusterSecretStore and ExternalSecret config in a single GitOps-managed unit. Individual ArgoCD Applications cover cert-manager, Kyverno and its policies, the GitHub Actions Runner Controller, monitoring, MLflow, Cloudflare Tunnel, the namespace controller, and the mittwald replicator. The Cloudflare Tunnel app uses a remote config pattern with the tunnel credentials stored separately from the chart.

---

## Secrets Management — External Secrets Operator

ESO is used throughout to eliminate hardcoded credentials. A ClusterSecretStore backed by AWS Secrets Manager serves as the single source of truth. ClusterExternalSecrets handle cross-namespace replication so workloads in any namespace can consume secrets without manual duplication. The bootstrap manifests set up the store and external secret from scratch, and a GitHub Actions workflow automates ESO installation on a fresh cluster.

---

## CI/CD — GitHub Actions

Workflows cover the full deployment lifecycle — cluster provisioning, ArgoCD bootstrap, ESO setup, AWS secret creation, application deployment to Kubernetes, Packer AMI builds, and IaC security scanning with KICS. Docker image build and push is scripted with multi-platform support for `linux/amd64` and `linux/arm64` via `docker buildx`.

---

## Observability — New Relic

New Relic APM is integrated at the cluster level via the `k8s-agents-operator`. An Instrumentation manifest handles automatic language agent injection into pods without modifying application code. A Node.js application with a dedicated New Relic Dockerfile demonstrates APM instrumentation in a containerised workload.

---

## Cluster Setup

A detailed KubeAdm setup guide covers the full process of standing up a multi-node cluster on VirtualBox VMs — kernel modules, sysctl tuning, swap disable, CRI-O install, kubeadm init, CNI (Calico or Cilium), CoreDNS external DNS fix, worker node join, metrics server, and default storage class. The guide is ordered correctly with CNI installed before workers join and before CoreDNS is patched.

---

## Shell Scripts

Utility scripts cover developer workstation bootstrapping (Docker, kubectl, Helm, Terraform across Debian, RHEL, Arch, and macOS), SSH key injection for CI/CD pipeline runners, memory monitoring with threshold alerting, and GitHub Actions runner registration as a systemd service.

---

## Stack

`Terraform` `Kubernetes` `Helm` `ArgoCD` `GitHub Actions` `External Secrets Operator` `Kyverno` `Cloudflare Tunnel` `cert-manager` `Longhorn` `Prometheus` `Grafana` `Splunk` `New Relic` `Packer` `Ansible` `AWS` `GCP` `Azure`

---

## Secrets

All secrets are managed via ESO — no hardcoded credentials in this repository. Placeholder references such as `<GITHUB_TOKEN>` should be replaced with ESO `ExternalSecret` references or GitHub Actions secrets before deploying.