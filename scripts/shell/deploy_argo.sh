#!/bin/bash

set -euxo pipefail

export DOCKER_URL="docker.io"

# List of required environment variables
required_vars_aks=(
    "DOCKER_URL"
    "DOCKER_USERNAME"
    "DOCKER_PASSWORD"
)

# Function to check if an environment variable is set
check_env_var() {
    local var_name=$1
    if [ -z "${!var_name}" ]; then
        echo "Please set ${var_name} environment variable. Exiting"
        exit 1
    fi
}

# Check each required environment variable
for var in "${required_vars_aks[@]}"; do
    check_env_var "$var"
done

echo "All required environment variables are set."

echo $DOCKER_PASSWORD | docker login "$DOCKER_URL" -u "$DOCKER_USERNAME" --password-stdin

# Check current path
script_dir_path=$(pwd)
echo "Script directory path: $script_dir_path"

# move to argocd manifest directory
cd "$GITHUB_WORKSPACE/Kubernetes_manifests/argo/non-HA" || exit 1

echo "Check argocd cli"
argocd version --client

# create argocd namespace
kubectl create namespace argocd
# Install argocd
kubectl apply -f install.yaml -n argocd

# Check if the installation was successful
if [ $? -ne 0 ]; then
    echo "ArgoCD installation failed. Exiting"
    exit 1
fi
