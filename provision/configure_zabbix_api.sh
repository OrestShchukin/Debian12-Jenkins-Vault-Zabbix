#!/usr/bin/env bash
set -euo pipefail

ZBX_URL="http://127.0.0.1:8081/api_jsonrpc.php"
ZBX_USER="Admin"
ZBX_PASS="zabbix"

HOST_NAME="devops-lab"
HOST_IP="192.168.56.10"
HOST_GROUP_NAME="Linux servers"

CURL_OPTS=(-s --connect-timeout 5 --max-time 15 -X POST -H 'Content-Type: application/json-rpc')

echo "[INFO] Waiting 20s for Zabbix services to stabilize..."
sleep 20

echo "[INFO] Starting Zabbix API configuration..."

api_call() {
  local payload="$1"
  curl "${CURL_OPTS[@]}" -d "$payload" "$ZBX_URL" || true
}

get_auth_token() {
  local attempts=20
  local delay=5

  for ((i=1; i<=attempts; i++)); do
    echo "[INFO] Authorizing in Zabbix API... attempt ${i}/${attempts}"

    RESPONSE=$(api_call "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"user.login\",
      \"params\": {
        \"username\": \"${ZBX_USER}\",
        \"password\": \"${ZBX_PASS}\"
      },
      \"id\": 1
    }")

    AUTH_TOKEN=$(echo "$RESPONSE" | jq -r '.result // empty')
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.data // .error.message // empty')

    if [ -n "$AUTH_TOKEN" ]; then
      echo "[INFO] Auth successful."
      return 0
    fi

    if [ -n "$ERROR_MSG" ]; then
      echo "[WARN] Auth API response: ${ERROR_MSG}"
    else
      echo "[WARN] Empty or invalid auth response."
    fi

    if [ "$i" -lt "$attempts" ]; then
      echo "[INFO] Waiting ${delay}s before retry..."
      sleep "$delay"
    fi
  done

  echo "[ERROR] Failed to get Zabbix auth token."
  exit 1
}

get_template_id() {
  echo "[INFO] Getting template ID for 'Linux by Zabbix agent'..."

  RESPONSE=$(api_call "{
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
  }")

  TEMPLATE_ID=$(echo "$RESPONSE" | jq -r '.result[0].templateid // empty')

  if [ -z "$TEMPLATE_ID" ]; then
    echo "[ERROR] Could not find template ID for 'Linux by Zabbix agent'."
    echo "$RESPONSE"
    exit 1
  fi

  echo "[INFO] Template ID: ${TEMPLATE_ID}"
}

get_or_create_host_group() {
  local attempts=10
  local delay=5

  for ((i=1; i<=attempts; i++)); do
    echo "[INFO] Getting or creating host group '${HOST_GROUP_NAME}'... attempt ${i}/${attempts}"

    RESPONSE=$(api_call "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"hostgroup.get\",
      \"params\": {
        \"output\": [\"groupid\", \"name\"],
        \"filter\": {
          \"name\": [\"${HOST_GROUP_NAME}\"]
        }
      },
      \"auth\": \"${AUTH_TOKEN}\",
      \"id\": 3
    }")

    GROUP_ID=$(echo "$RESPONSE" | jq -r '.result[0].groupid // empty')

    if [ -n "$GROUP_ID" ]; then
      echo "[INFO] Host group found: ${GROUP_ID}"
      return 0
    fi

    echo "[INFO] Host group not found, creating it..."

    RESPONSE=$(api_call "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"hostgroup.create\",
      \"params\": {
        \"name\": \"${HOST_GROUP_NAME}\"
      },
      \"auth\": \"${AUTH_TOKEN}\",
      \"id\": 4
    }")

    GROUP_ID=$(echo "$RESPONSE" | jq -r '.result.groupids[0] // empty')
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.data // .error.message // empty')

    if [ -n "$GROUP_ID" ]; then
      echo "[INFO] Host group created: ${GROUP_ID}"
      return 0
    fi

    if [ -n "$ERROR_MSG" ]; then
      echo "[WARN] hostgroup.create API error: ${ERROR_MSG}"
    else
      echo "[WARN] Empty or invalid hostgroup.create response."
    fi

    if [ "$i" -lt "$attempts" ]; then
      echo "[INFO] Waiting ${delay}s before retry..."
      sleep "$delay"
    fi
  done

  echo "[ERROR] Failed to get or create host group '${HOST_GROUP_NAME}'."
  exit 1
}

get_or_create_host() {
  local attempts=10
  local delay=5

  echo "[INFO] Checking if host '${HOST_NAME}' already exists..."

  RESPONSE=$(api_call "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.get\",
    \"params\": {
      \"output\": [\"hostid\", \"host\"],
      \"filter\": {
        \"host\": [\"${HOST_NAME}\"]
      }
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 5
  }")

  HOST_ID=$(echo "$RESPONSE" | jq -r '.result[0].hostid // empty')

  if [ -n "$HOST_ID" ]; then
    echo "[INFO] Host already exists with ID ${HOST_ID}."
    return 0
  fi

  for ((i=1; i<=attempts; i++)); do
    echo "[INFO] Creating host ${HOST_NAME}... attempt ${i}/${attempts}"
    echo "[INFO] Waiting for Zabbix API response..."

    RESPONSE=$(api_call "{
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
    }")

    if [ -z "$RESPONSE" ]; then
      echo "[WARN] No response received from Zabbix API."
    else
      echo "[INFO] Response received from Zabbix API."
    fi

    HOST_ID=$(echo "$RESPONSE" | jq -r '.result.hostids[0] // empty')
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.data // .error.message // empty')

    if [ -n "$HOST_ID" ]; then
      echo "[INFO] Host created successfully with ID ${HOST_ID}."
      return 0
    fi

    if [ -n "$ERROR_MSG" ]; then
      echo "[WARN] host.create API error: ${ERROR_MSG}"
    else
      echo "[WARN] Empty or invalid host.create response."
    fi
    echo "[INFO] host.create raw response:"
    echo "$RESPONSE"


    echo "[INFO] Re-checking whether host was created despite missing response..."
    sleep 2

    RESPONSE=$(api_call "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"host.get\",
      \"params\": {
        \"output\": [\"hostid\", \"host\"],
        \"filter\": {
          \"host\": [\"${HOST_NAME}\"]
        }
      },
      \"auth\": \"${AUTH_TOKEN}\",
      \"id\": 61
    }")

    HOST_ID=$(echo "$RESPONSE" | jq -r '.result[0].hostid // empty')

    if [ -n "$HOST_ID" ]; then
      echo "[INFO] Host appeared after re-check. Using existing host ID ${HOST_ID}."
      return 0
    fi

    if [ "$i" -lt "$attempts" ]; then
      echo "[INFO] Waiting ${delay}s before retry..."
      sleep "$delay"
    fi
  done

  echo "[ERROR] Failed to create host '${HOST_NAME}'."
  exit 1
}

get_host_interface_id() {
  echo "[INFO] Getting host interface ID..."

  RESPONSE=$(api_call "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"hostinterface.get\",
    \"params\": {
      \"output\": [\"interfaceid\", \"ip\", \"port\"],
      \"hostids\": \"${HOST_ID}\"
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 7
  }")

  INTERFACE_ID=$(echo "$RESPONSE" | jq -r '.result[0].interfaceid // empty')

  if [ -z "$INTERFACE_ID" ]; then
    echo "[ERROR] Failed to get host interface ID."
    echo "$RESPONSE"
    exit 1
  fi

  echo "[INFO] Host interface ID: ${INTERFACE_ID}"
}

delete_default_zabbix_host() {
  echo "[INFO] Checking default 'Zabbix server' host..."

  RESPONSE=$(api_call "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.get\",
    \"params\": {
      \"output\": [\"hostid\", \"host\"],
      \"filter\": {
        \"host\": [\"Zabbix server\"]
      }
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 8
  }")

  DEFAULT_HOST_ID=$(echo "$RESPONSE" | jq -r '.result[0].hostid // empty')

  if [ -n "$DEFAULT_HOST_ID" ]; then
    echo "[INFO] Deleting default 'Zabbix server' host..."

    RESPONSE=$(api_call "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"host.delete\",
      \"params\": [\"${DEFAULT_HOST_ID}\"],
      \"auth\": \"${AUTH_TOKEN}\",
      \"id\": 9
    }")

    echo "[INFO] host.delete response:"
    echo "$RESPONSE"
  else
    echo "[INFO] Default 'Zabbix server' host not found."
  fi
}

create_item_if_missing() {
  local item_name="$1"
  local item_key="$2"

  echo "[INFO] Checking item ${item_key}..."

  RESPONSE=$(api_call "{
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
  }")

  ITEM_ID=$(echo "$RESPONSE" | jq -r '.result[0].itemid // empty')

  if [ -z "$ITEM_ID" ]; then
    echo "[INFO] Creating item ${item_name}..."

    RESPONSE=$(api_call "{
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
    }")

  #  echo "[INFO] item.create response for ${item_key}:"
  #  echo "$RESPONSE"

    ITEM_ID=$(echo "$RESPONSE" | jq -r '.result.itemids[0] // empty')
  else
    echo "[INFO] Item ${item_key} already exists with ID ${ITEM_ID}."
  fi

  if [ -z "$ITEM_ID" ]; then
    echo "[ERROR] Failed to create item ${item_name} (${item_key})."
    exit 1
  fi
}

create_trigger_if_missing() {
  local description="$1"
  local expression="$2"

  echo "[INFO] Checking trigger '${description}'..."

  RESPONSE=$(api_call "{
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
  }")

  TRIGGER_ID=$(echo "$RESPONSE" | jq -r '.result[0].triggerid // empty')

  if [ -z "$TRIGGER_ID" ]; then
    echo "[INFO] Creating trigger ${description}..."

    RESPONSE=$(api_call "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"trigger.create\",
      \"params\": {
        \"description\": \"${description}\",
        \"expression\": \"${expression}\",
        \"priority\": 4
      },
      \"auth\": \"${AUTH_TOKEN}\",
      \"id\": 21
    }")

    # echo "[INFO] trigger.create response for ${description}:"
    # echo "$RESPONSE"

    TRIGGER_ID=$(echo "$RESPONSE" | jq -r '.result.triggerids[0] // empty')
  else
    echo "[INFO] Trigger '${description}' already exists with ID ${TRIGGER_ID}."
  fi

  if [ -z "$TRIGGER_ID" ]; then
    echo "[ERROR] Failed to create trigger '${description}'."
    exit 1
  fi
}

get_auth_token
get_template_id
get_or_create_host_group
get_or_create_host
get_host_interface_id
delete_default_zabbix_host

create_item_if_missing "Jenkins status" "service.jenkins"
create_item_if_missing "Vault status" "service.vault"
create_item_if_missing "Zabbix server status" "service.zabbix_server"

create_trigger_if_missing "Jenkins is down" "last(/${HOST_NAME}/service.jenkins)=0"
create_trigger_if_missing "Vault is down" "last(/${HOST_NAME}/service.vault)=0"
create_trigger_if_missing "Zabbix server is down" "last(/${HOST_NAME}/service.zabbix_server)=0"

echo "[INFO] Zabbix API configuration completed successfully."