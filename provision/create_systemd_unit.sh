#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Creating systemd unit for devops-stack ..."

cat > /etc/systemd/system/devops-stack.service <<'EOF'
[Unit]
Description=DevOps Test Stack (Docker Compose)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/devops-stack/docker
ExecStart=/usr/bin/docker compose up -d --build
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable devops-stack.service

echo "[INFO] Starting Devops-test service..."
systemctl start devops-stack

echo "[INFO] systemd unit created."