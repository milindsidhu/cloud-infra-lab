#!/bin/bash

SERVICE_NAME="github-runner"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_DIR="$HOME/actions-runner"

# Ensure scripts are executable
chmod +x "$SCRIPT_DIR/run.sh"
chmod +x "$SCRIPT_DIR/svc.sh"

# Create the systemd service file
cat << EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Run Github Runner Service
After=network.target

[Service]
ExecStart=$SCRIPT_DIR/run.sh
ExecStop=$SCRIPT_DIR/svc.sh stop
Restart=always
RestartSec=10
User=root
WorkingDirectory=$SCRIPT_DIR
StandardOutput=journal
StandardError=journal
Environment="RUNNER_ALLOW_RUNASROOT=true"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl reset-failed "$SERVICE_NAME"
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

echo "Service '$SERVICE_NAME' has been created and started."
