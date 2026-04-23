#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Configuring Docker DNS..."

mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<'EOF'
{
  "dns": ["1.1.1.1", "8.8.8.8"],
  "ipv6": false
}
EOF

systemctl restart docker

echo "[INFO] Docker DNS configured."