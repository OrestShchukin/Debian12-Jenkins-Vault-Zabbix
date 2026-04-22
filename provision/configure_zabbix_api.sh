#!/usr/bin/env bash
set -euo pipefail

ZBX_URL="http://127.0.0.1:8081/api_jsonrpc.php"
ZBX_USER="Admin"
ZBX_PASS="zabbix"

HOST_NAME="devops-lab"
HOST_IP="192.168.56.10"

echo "[INFO] Authorizing in Zabbix API..."

AUTH_TOKEN=""
for i in {1..20}; do
  RESPONSE=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
    -d "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"user.login\",
      \"params\": {
        \"username\": \"${ZBX_USER}\",
        \"password\": \"${ZBX_PASS}\"
      },
      \"id\": 1
    }" "$ZBX_URL" || true)

  AUTH_TOKEN=$(echo "$RESPONSE" | jq -r '.result // empty')
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.data // .error.message // empty')

  if [ -n "$AUTH_TOKEN" ]; then
    break
  fi

  echo "[INFO] Zabbix auth not ready yet... attempt $i/20"
  if [ -n "$ERROR_MSG" ]; then
    echo "[INFO] API response: $ERROR_MSG"
  fi
  sleep 5
done

if [ -z "$AUTH_TOKEN" ]; then
  echo "[ERROR] Failed to get Zabbix auth token."
  exit 1
fi

echo "[INFO] Auth successful."

echo "[INFO] Getting Linux by Zabbix agent template ID..."
TEMPLATE_ID=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"template.get\",
    \"params\": {
      \"output\": [\"templateid\", \"host\"],
      \"filter\": {
        \"host\": [\"Linux by Zabbix agent\"]
      }
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 2
  }" "$ZBX_URL" | jq -r '.result[0].templateid // empty')

if [ -z "$TEMPLATE_ID" ]; then
  echo "[ERROR] Could not find template ID for 'Linux by Zabbix agent'."
  exit 1
fi

echo "[INFO] Checking if host already exists..."
HOST_ID=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.get\",
    \"params\": {
      \"output\": [\"hostid\", \"host\"],
      \"filter\": {
        \"host\": [\"${HOST_NAME}\"]
      }
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 3
  }" "$ZBX_URL" | jq -r '.result[0].hostid // empty')

if [ -z "$HOST_ID" ]; then
  echo "[INFO] Creating host ${HOST_NAME}..."

  # знайдемо або створимо групу
  GROUP_ID=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
    -d "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"hostgroup.get\",
      \"params\": {
        \"output\": [\"groupid\", \"name\"],
        \"filter\": {
          \"name\": [\"Linux servers\"]
        }
      },
      \"auth\": \"${AUTH_TOKEN}\",
      \"id\": 4
    }" "$ZBX_URL" | jq -r '.result[0].groupid // empty')

  if [ -z "$GROUP_ID" ]; then
    GROUP_ID=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
      -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"hostgroup.create\",
        \"params\": {
          \"name\": \"Linux servers\"
        },
        \"auth\": \"${AUTH_TOKEN}\",
        \"id\": 5
      }" "$ZBX_URL" | jq -r '.result.groupids[0] // empty')
  fi

  HOST_ID=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
    -d "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"host.create\",
      \"params\": {
        \"host\": \"${HOST_NAME}\",
        \"interfaces\": [
          {
            \"type\": 1,
            \"main\": 1,
            \"useip\": 1,
            \"ip\": \"${HOST_IP}\",
            \"dns\": \"\",
            \"port\": \"10050\"
          }
        ],
        \"groups\": [
          {
            \"groupid\": \"${GROUP_ID}\"
          }
        ],
        \"templates\": [
          {
            \"templateid\": \"${TEMPLATE_ID}\"
          }
        ]
      },
      \"auth\": \"${AUTH_TOKEN}\",
      \"id\": 6
    }" "$ZBX_URL" | jq -r '.result.hostids[0] // empty')
else
  echo "[INFO] Host already exists with ID ${HOST_ID}."
fi

if [ -z "$HOST_ID" ] || [ "HOST_ID" = "null" ]; then
  echo "[ERROR] Failed to create or get host ID."
  exit 1
fi

echo "[INFO] Getting host interface ID..."
INTERFACE_ID=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"hostinterface.get\",
    \"params\": {
      \"output\": [\"interfaceid\", \"ip\", \"port\"],
      \"hostids\": \"${HOST_ID}\"
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 7
  }" "$ZBX_URL" | jq -r '.result[0].interfaceid // empty')

if [ -z "$INTERFACE_ID" ]; then
  echo "[ERROR] Failed to get host interface ID."
  exit 1
fi

echo "[INFO] Host interface ID: ${INTERFACE_ID}"


create_item_if_missing() {
  local item_name="$1"
  local item_key="$2"

  ITEM_ID=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
    -d "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"item.get\",
      \"params\": {
        \"output\": [\"itemid\", \"name\", \"key_\"],
        \"hostids\": \"${HOST_ID}\",
        \"filter\": {
          \"key_\": [\"${item_key}\"]
        }
      },
      \"auth\": \"${AUTH_TOKEN}\",
      \"id\": 10
    }" "$ZBX_URL" | jq -r '.result[0].itemid // empty')

  if [ -z "$ITEM_ID" ]; then
    echo "[INFO] Creating item ${item_name}..."

    RESPONSE=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
      -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"item.create\",
        \"params\": {
          \"name\": \"${item_name}\",
          \"key_\": \"${item_key}\",
          \"hostid\": \"${HOST_ID}\",
          \"interfaceid\": \"${INTERFACE_ID}\",
          \"type\": 0,
          \"value_type\": 3,
          \"delay\": \"30s\"
        },
        \"auth\": \"${AUTH_TOKEN}\",
        \"id\": 11
      }" "$ZBX_URL")

    echo "$RESPONSE"

    ITEM_ID=$(echo "$RESPONSE" | jq -r '.result.itemids[0] // empty')
  fi

  if [ -z "$ITEM_ID" ]; then
    echo "[ERROR] Failed to create item ${item_name} (${item_key})."
    exit 1
  fi
}

create_trigger_if_missing() {
  local description="$1"
  local expression="$2"

  TRIGGER_ID=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
    -d "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"trigger.get\",
      \"params\": {
        \"output\": [\"triggerid\", \"description\"],
        \"hostids\": \"${HOST_ID}\",
        \"filter\": {
          \"description\": [\"${description}\"]
        }
      },
      \"auth\": \"${AUTH_TOKEN}\",
      \"id\": 20
    }" "$ZBX_URL" | jq -r '.result[0].triggerid // empty')

  if [ -z "$TRIGGER_ID" ]; then
    echo "[INFO] Creating trigger ${description}..."
    curl -s -X POST -H 'Content-Type: application/json-rpc' \
      -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"trigger.create\",
        \"params\": {
          \"description\": \"${description}\",
          \"expression\": \"${expression}\",
          \"priority\": 4
        },
        \"auth\": \"${AUTH_TOKEN}\",
        \"id\": 21
      }" "$ZBX_URL" > /dev/null
  fi
}

echo "[INFO] Checking default 'Zabbix server' host..."

DEFAULT_HOST_ID=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.get\",
    \"params\": {
      \"output\": [\"hostid\", \"host\"],
      \"filter\": {
        \"host\": [\"Zabbix server\"]
      }
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 100
  }" "$ZBX_URL" | jq -r '.result[0].hostid // empty')

if [ -n "$DEFAULT_HOST_ID" ]; then
  echo "[INFO] Deleting default 'Zabbix server' host..."

  RESPONSE=$(curl -s -X POST -H 'Content-Type: application/json-rpc' \
    -d "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"host.delete\",
      \"params\": [\"${DEFAULT_HOST_ID}\"],
      \"auth\": \"${AUTH_TOKEN}\",
      \"id\": 101
    }" "$ZBX_URL")

  echo "$RESPONSE"
else
  echo "[INFO] Default 'Zabbix server' host not found."
fi

create_item_if_missing "Jenkins status" "service.jenkins"
create_item_if_missing "Vault status" "service.vault"
create_item_if_missing "Zabbix server status" "service.zabbix_server"

create_trigger_if_missing "Jenkins is down" "last(/${HOST_NAME}/service.jenkins)=0"
create_trigger_if_missing "Vault is down" "last(/${HOST_NAME}/service.vault)=0"
create_trigger_if_missing "Zabbix server is down" "last(/${HOST_NAME}/service.zabbix_server)=0"

echo "[INFO] Zabbix API configuration completed successfully."