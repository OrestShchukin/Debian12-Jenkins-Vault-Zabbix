#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Installing Zabbix Agent 2..."

wget -O /tmp/zabbix-release.deb https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian12_all.deb
dpkg -i /tmp/zabbix-release.deb
apt-get update
apt-get install -y zabbix-agent2

systemctl enable zabbix-agent2

echo "[INFO] Zabbix Agent 2 installed."