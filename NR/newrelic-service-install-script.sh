#!/bin/bash

set euo -pipefail

# ========================
# Configurable Variables
# ========================
http_proxy=$(get_octopusvariable "HTTP_PROXY")
ENV=$(get_octopusvariable "PNP.Environment.Alias")
TENANT=$(get_octopusvariable "FinOps.client")
DOCKER_USERNAME=$(get_octopusvariable "PNP.Docker.Username")
DOCKER_PASSWORD=$(get_octopusvariable "PNP.Docker.Password")
DOCKER_ARTIFACTORY=$(get_octopusvariable "PNP.Docker.Registry")
NON_PROD_NR_KEY=$(get_octopusvariable "PNP.NON_PROD.NR_LICENSEKEY")
PROD_NR_KEY=$(get_octopusvariable "PNP.PROD.NR_LICENSEKEY")
DESTRUCTIVE=$(get_octopusvariable "DESTRUCTIVE_NEWRELIC_BUILD")
DESTRUCTIVE="${DESTRUCTIVE:-false}"

BASE_NAME="${basename:-datahub}"
SERVICE_NAME="newrelic-infra-agent"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
NEW_RELIC_INFRA_IMAGE=""


check_env_and_tenant() {
    if [[ -z "$ENV" ]]; then
        echo "ENV variable is not set. Please set it before proceeding."
        exit 1
    fi

    if [[ -z "$TENANT" ]]; then
        echo "TENANT variable is not set. Please set it before proceeding."
        exit 1
    fi

    echo "ENV and TENANT are both set: ENV=$ENV, TENANT=$TENANT"
}

check_env_and_tenant

# Docker login
echo "Logging into Docker Artifactory..."
echo "$DOCKER_PASSWORD" | docker login "$DOCKER_ARTIFACTORY" --username "$DOCKER_USERNAME" --password-stdin
echo "Pulling the NR Infra Agent Image..."
docker pull $NEW_RELIC_INFRA_IMAGE

# this will be displayed in the New Relic UI
if [[ "$ENV" == "prod" ]]; then
    CONTAINER_NAME=$TENANT.pnp-$BASE_NAME
    DISPLAY_NAME=dh-$TENANT.pnp-$BASE_NAME
else
    CONTAINER_NAME=$TENANT.pnp-$ENV-$BASE_NAME
    DISPLAY_NAME=dh-$TENANT.pnp-$ENV-$BASE_NAME
fi

# New Relic Infrastructure Agent Environment Variables
if [[ "$ENV" == "prod" ]]; then
    NRIA_LICENSE_KEY="$PROD_NR_KEY"
else
    NRIA_LICENSE_KEY="$NON_PROD_NR_KEY"
fi



# ========================
# Check if service should be skipped (non-destructive mode)
# ========================
if [[ "${DESTRUCTIVE,,}" != "true" ]]; then
    echo "Non-destructive mode: Validating if service should be skipped."

    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "Docker Container Info:"
        sudo docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.CreatedAt}}"

        # Check if the container is running with the expected image
        running_image=$(sudo docker ps --filter "name=$CONTAINER_NAME" --format "{{.Image}}")
        if [[ -n "$running_image" ]]; then
            if [[ "$running_image" == "$NEW_RELIC_INFRA_IMAGE" ]]; then
                echo -e "\nRunning container image matches expected image. Skipping update."

                echo ""
                echo "Systemd Service Info:"
                SERVICE_STATUS=$(sudo systemctl list-units --type=service | grep "$SERVICE_NAME")

                if [[ -n "$SERVICE_STATUS" ]]; then
                    printf "%-40s | %-10s | %-10s | %-40s\n" "SERVICE NAME" "CONFIG" "STATE" "DESCRIPTION"
                    echo "$SERVICE_STATUS" | awk '{printf "%-40s | %-10s | %-10s | %-40s\n", $1, $2, $3, substr($0, index($0,$5))}'
                else
                    echo "Service $SERVICE_NAME not found in systemd."
                fi

                echo ""
                echo "Exiting script as the service is already running with the correct configuration."
                exit 0
            else
                echo -e "\nImage mismatch:"
                echo "Expected: $NEW_RELIC_INFRA_IMAGE"
                echo "Found:    $running_image"
                echo "Proceeding to recreate the service..."
            fi
        else
            echo -e "\nContainer $CONTAINER_NAME is not running despite service being active. Proceeding..."
        fi
    else
        echo "Service: $SERVICE_NAME is not running. Continuing..."
    fi
else
    echo "Destructive mode enabled: Skipping validation and proceeding to recreate the service unconditionally."
fi


# Ensure directory for systemd service exists
if [ ! -d "$(dirname "$SERVICE_FILE")" ]; then
    echo "Creating directory: $(dirname "$SERVICE_FILE")"
    sudo mkdir -p "$(dirname "$SERVICE_FILE")"
fi

# Check if the service exists
if systemctl list-units --all --type=service | grep -q "$SERVICE_NAME"; then
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "Stopping running service: $SERVICE_NAME"
        sudo systemctl stop "$SERVICE_NAME"
        sudo systemctl disable "$SERVICE_NAME"
        echo "Service $SERVICE_NAME stopped and disabled."
    else
        echo "Service $SERVICE_NAME is not running. Disabling it."
        sudo systemctl disable "$SERVICE_NAME"
        echo "Service $SERVICE_NAME disabled."
    fi
else
    echo "Service $SERVICE_NAME does not exist. Skipping."
fi


# Check if the systemd service file exists, and delete it if it does
if [ -f "$SERVICE_FILE" ]; then
    echo "Deleting existing systemd service file: $SERVICE_FILE"
    sudo rm -f "$SERVICE_FILE"
fi


# ========================
# Create the systemd service file
# ========================
cat <<EOF | sudo tee $SERVICE_FILE
[Unit]
Description=New Relic Infrastructure Agent Service
Requires=docker.service
After=docker.service

[Service]
Environment="CONTAINER_NAME=$CONTAINER_NAME"
Environment="NEW_RELIC_INFRA_IMAGE=$NEW_RELIC_INFRA_IMAGE"
Environment="DISPLAY_NAME=$DISPLAY_NAME"



ExecStart=/usr/bin/docker run \\
  --network=host \\
  --cap-add=SYS_PTRACE \\
  --privileged \\
  --pid=host \\
  --cgroupns=host \\
  --volume /:/host:ro \\
  --volume /var/run/docker.sock:/var/run/docker.sock \\
  --env NRIA_DISPLAY_NAME=$DISPLAY_NAME \\
  --env NRIA_DOCKER_ENABLED=true \\
  --env NRIA_DOCKER_METRICS=true \\
  --env NRIA_ENABLE_PROCESS_METRICS=true \\
  --env NRIA_LOG_LEVEL=info \\
  --env NRIA_LOG_FORWARD=false \\
  --env NRIA_CLOUD_MAX_RETRY_COUNT=3 \\
  --env NRIA_LICENSE_KEY=$NRIA_LICENSE_KEY \\
  --env HTTPS_PROXY=$http_proxy \\
  --name $CONTAINER_NAME \\
  $NEW_RELIC_INFRA_IMAGE

ExecStop=/usr/bin/docker stop $CONTAINER_NAME
ExecStopPost=/usr/bin/docker rm $CONTAINER_NAME

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo ""
echo "NewRelic Infrastructure Agent Service file created, located at: $SERVICE_FILE"

# ========================
# Reload systemd and start the service
# ========================
echo "Reloading systemd and starting service: $SERVICE_NAME"
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
echo "Starting service: $SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"
sleep 30
# ========================
# Show service status
# ========================
sudo systemctl status "$SERVICE_NAME" --no-pager


# ========================
# Validate service and container
# ========================
validate_newrelic_infra_start() {
    echo ""
    echo "Validating service: $SERVICE_NAME"

    # Wait a moment to let systemd settle
    sleep 2

    stop_and_disable_service() {
        echo ""
        echo "Stopping and disabling failed service: $SERVICE_NAME"
        sudo systemctl stop "$SERVICE_NAME"
        sudo systemctl disable "$SERVICE_NAME"
        echo "Service $SERVICE_NAME stopped and disabled. Exiting..."
    }

    # Check if the service is in a failed state
    if sudo systemctl is-failed --quiet "$SERVICE_NAME"; then
        echo "Service $SERVICE_NAME is in a FAILED state."
        echo ""
        echo "===== systemctl status output ====="
        sudo systemctl status "$SERVICE_NAME" --no-pager
        echo ""
        echo "===== Docker logs for $CONTAINER_NAME ====="
        sudo docker logs "$CONTAINER_NAME" 2>&1 | tail -n 15
        stop_and_disable_service
        exit 1
    fi

    # Check docker logs for common startup issues
    if sudo docker logs "$CONTAINER_NAME" 2>&1 | grep -Eqi "Error response from daemon|Authentication is required|No such container|status=125"; then
        echo "Detected error during Docker startup for $SERVICE_NAME."
        echo ""
        echo "===== Docker logs for $CONTAINER_NAME ====="
        sudo docker logs "$CONTAINER_NAME" 2>&1 | tail -n 15
        stop_and_disable_service
        exit 1
    fi

    # Check if container is running
    if ! sudo docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -qw "$CONTAINER_NAME"; then
        echo "Container $CONTAINER_NAME is not running despite service being started."
        echo ""
        echo "===== Docker PS -a output ====="
        sudo docker ps -a --filter "name=$CONTAINER_NAME"
        echo ""
        echo "===== Docker logs for $CONTAINER_NAME ====="
        sudo docker logs "$CONTAINER_NAME" 2>&1 | tail -n 10
        echo ""
        echo "===== systemctl status output ====="
        sudo systemctl status "$SERVICE_NAME" --no-pager
        stop_and_disable_service
        exit 1
    fi

    echo "$SERVICE_NAME is running correctly with container: $CONTAINER_NAME"
}

validate_newrelic_infra_start
