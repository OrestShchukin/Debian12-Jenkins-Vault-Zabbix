#!/usr/bin/env bash
set -euo pipefail

ZBX_URL="http://127.0.0.1:8081/api_jsonrpc.php"

echo "[INFO] Waiting for Zabbix API login to become available..."

for i in {1..60}; do
  RESPONSE=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
    -d '{
      "jsonrpc": "2.0",
      "method": "user.login",
      "params": {
        "username": "Admin",
        "password": "zabbix"
      },
      "id": 1
    }' "$ZBX_URL" || true)

  TOKEN=$(echo "$RESPONSE" | jq -r '.result // empty')
  ERROR=$(echo "$RESPONSE" | jq -r '.error.data // .error.message // empty')

  if [ -n "$TOKEN" ]; then
    echo "[INFO] Zabbix API login is ready."
    exit 0
  fi

  echo "[INFO] Zabbix API not ready yet... attempt $i/60"
  if [ -n "$ERROR" ]; then
    echo "[INFO] API response: $ERROR"
  fi

  sleep 5
done

echo "[ERROR] Zabbix API login did not become ready in time."
exit 1