#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Disabling IPv6 in VM..."

cat > /etc/sysctl.d/99-disable-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sysctl --system

echo "[INFO] Configuring Docker DNS..."

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "dns": ["1.1.1.1", "8.8.8.8"]
}
EOF

systemctl restart docker

echo "[INFO] Network configuration completed."