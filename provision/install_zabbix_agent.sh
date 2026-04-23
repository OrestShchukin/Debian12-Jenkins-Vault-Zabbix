#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Installing Zabbix Agent 2..."

ZABBIX_DEB_URL="https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian12_all.deb"
ZABBIX_DEB_FILE="/tmp/zabbix-release.deb"

for i in 1 2 3; do
  echo "[INFO] Downloading Zabbix release package... attempt ${i}/3"
  if wget -O "$ZABBIX_DEB_FILE" "$ZABBIX_DEB_URL"; then
    echo "[INFO] Download successful."
    break
  fi

  if [ "$i" -lt 3 ]; then
    echo "[WARN] Download failed. Retrying in 10s..."
    sleep 10
  else
    echo "[ERROR] Failed to download Zabbix release package after 3 attempts."
    exit 1
  fi
done

dpkg -i "$ZABBIX_DEB_FILE"
apt-get update
apt-get install -y zabbix-agent2

systemctl enable zabbix-agent2

echo "[INFO] Zabbix Agent 2 installed."