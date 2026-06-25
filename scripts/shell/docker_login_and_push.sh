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

docker --version

echo $DOCKER_PASSWORD | docker login "$DOCKER_URL" -u "$DOCKER_USERNAME" --password-stdin

docker logout "$DOCKER_URL"

# # Login to Docker registry
# echo "Logging in to Docker registry..."
# echo "$DOCKER_PASSWORD" | docker login "$DOCKER_URL" -u "$DOCKER_USERNAME" --password-stdin

# # Check if the login was successful
# if [ $? -ne 0 ]; then
#     echo "Docker login failed. Exiting"
#     exit 1
# fi
