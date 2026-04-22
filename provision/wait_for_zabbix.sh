#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Waiting for Zabbix API to become available..."

for i in {1..60}; do
  if curl -s http://127.0.0.1:8081/api_jsonrpc.php >/dev/null 2>&1; then
    echo "[INFO] Zabbix API is reachable."
    exit 0
  fi
  echo "[INFO] Zabbix not ready yet... attempt $i/60"
  sleep 5
done

echo "[ERROR] Zabbix API did not become ready in time."
exit 1