#!/usr/bin/env bash
set -euo pipefail

ZBX_URL="http://127.0.0.1/api_jsonrpc.php"
ZBX_HOST_HEADER="zabbix.local"
ZBX_USER="Admin"
ZBX_PASS="zabbix"

HOST_NAME="devops-lab"
HOST_IP="192.168.56.10"
HOST_GROUP_NAME="Linux servers"
TEMPLATE_NAME="Linux by Zabbix agent"

log() {
  echo "[INFO] $*" >&2
}

error() {
  echo "[ERROR] $*" >&2
}

api_call() {
  local payload="$1"

  curl -sS -X POST \
    -H 'Content-Type: application/json-rpc' \
    -H "Host: ${ZBX_HOST_HEADER}" \
    -d "$payload" \
    "$ZBX_URL"
}

is_valid_json() {
  local input="$1"
  echo "$input" | jq empty >/dev/null 2>&1
}

extract_json_error() {
  local input="$1"
  echo "$input" | jq -r '.error.data // .error.message // empty' 2>/dev/null || true
}

require_valid_json() {
  local response="$1"
  local context="$2"

  if ! is_valid_json "$response"; then
    error "${context} did not return valid JSON."
    echo "$response"
    exit 1
  fi
}

api_call_checked() {
  local payload="$1"
  local context="$2"
  local response

  response="$(api_call "$payload")"
  require_valid_json "$response" "$context"
  echo "$response"
}

api_call_retry() {
  local payload="$1"
  local context="$2"
  local attempts="${3:-20}"
  local sleep_seconds="${4:-5}"

  local response=""
  local json_error=""

  for ((i=1; i<=attempts; i++)); do
    response="$(api_call "$payload" || true)"

    if is_valid_json "$response"; then
      json_error="$(extract_json_error "$response")"

      if [ -z "$json_error" ]; then
        echo "$response"
        return 0
      fi
    fi

    log "${context} not ready yet... attempt ${i}/${attempts}"
    if [ -n "$json_error" ]; then
      log "API response: ${json_error}"
    elif [ -n "$response" ]; then
      log "Non-JSON/invalid response received."
      echo "$response"
    fi

    sleep "$sleep_seconds"
  done

  error "${context} failed after ${attempts} attempts."
  if [ -n "$response" ]; then
    echo "$response"
  fi
  exit 1
}

get_auth_token() {
  local response
  response="$(api_call_retry "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"user.login\",
    \"params\": {
      \"username\": \"${ZBX_USER}\",
      \"password\": \"${ZBX_PASS}\"
    },
    \"id\": 1
  }" "Zabbix API login" 30 5)"

  echo "$response" | jq -r '.result // empty'
}

get_host_id_by_name() {
  local host_name="$1"
  local response

  response="$(api_call_checked "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.get\",
    \"params\": {
      \"output\": [\"hostid\", \"host\"],
      \"filter\": {
        \"host\": [\"${host_name}\"]
      }
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 10
  }" "host.get (${host_name})")"

  echo "$response" | jq -r '.result[0].hostid // empty'
}

get_template_id_by_name() {
  local template_name="$1"
  local response

  response="$(api_call_retry "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"template.get\",
    \"params\": {
      \"output\": [\"templateid\", \"host\"],
      \"filter\": {
        \"host\": [\"${template_name}\"]
      }
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 20
  }" "template.get (${template_name})" 20 5)"

  echo "$response" | jq -r '.result[0].templateid // empty'
}

get_or_create_group_id() {
  local group_name="$1"
  local response
  local group_id

  response="$(api_call_checked "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"hostgroup.get\",
    \"params\": {
      \"output\": [\"groupid\", \"name\"],
      \"filter\": {
        \"name\": [\"${group_name}\"]
      }
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 30
  }" "hostgroup.get (${group_name})")"

  group_id="$(echo "$response" | jq -r '.result[0].groupid // empty')"

  if [ -n "$group_id" ]; then
    echo "$group_id"
    return 0
  fi

  log "Creating host group ${group_name}..."
  response="$(api_call_checked "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"hostgroup.create\",
    \"params\": {
      \"name\": \"${group_name}\"
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 31
  }" "hostgroup.create (${group_name})")"

  group_id="$(echo "$response" | jq -r '.result.groupids[0] // empty')"

  if [ -z "$group_id" ]; then
    error "Failed to create host group ${group_name}."
    echo "$response"
    exit 1
  fi

  echo "$group_id"
}

delete_default_zabbix_host_if_exists() {
  local default_host_id
  local response

  default_host_id="$(get_host_id_by_name "Zabbix server")"

  if [ -z "$default_host_id" ]; then
    log "Default 'Zabbix server' host not found."
    return 0
  fi

  log "Deleting default 'Zabbix server' host..."
  response="$(api_call_checked "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.delete\",
    \"params\": [\"${default_host_id}\"],
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 40
  }" "host.delete (Zabbix server)")"

  log "Default host deleted."
  echo "$response" >/dev/null
}

create_host_if_missing() {
  local response
  local host_id
  local api_error

  host_id="$(get_host_id_by_name "${HOST_NAME}")"

  if [ -n "$host_id" ]; then
    log "Host ${HOST_NAME} already exists with ID ${host_id}."
    echo "$host_id"
    return 0
  fi

  for i in {1..10}; do
    log "Creating host ${HOST_NAME}... attempt ${i}/10"

    response="$(api_call "{
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
      \"id\": 50
    }" || true)"

    if ! is_valid_json "$response"; then
      log "host.create (${HOST_NAME}) returned non-JSON response."
      sleep 5
      continue
    fi

    host_id="$(echo "$response" | jq -r '.result.hostids[0] // empty')"
    if [ -n "$host_id" ]; then
      echo "$host_id"
      return 0
    fi

    api_error="$(extract_json_error "$response")"

    if echo "$api_error" | grep -q 'already exists'; then
      log "Host ${HOST_NAME} already exists according to API, re-reading host ID..."
      host_id="$(get_host_id_by_name "${HOST_NAME}")"
      if [ -n "$host_id" ]; then
        echo "$host_id"
        return 0
      fi
    fi

    if [ -n "$api_error" ]; then
      log "API response: ${api_error}"
    else
      log "Unknown host.create response:"
      echo "$response" >&2
    fi

    sleep 5
  done

  error "Failed to create or retrieve host ${HOST_NAME} after retries."
  return 1
}

get_host_interface_id() {
  local host_id="$1"
  local response

  response="$(api_call_retry "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"hostinterface.get\",
    \"params\": {
      \"output\": [\"interfaceid\", \"ip\", \"port\"],
      \"hostids\": \"${host_id}\"
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 60
  }" "hostinterface.get (${host_id})" 10 3)"

  echo "$response" | jq -r '.result[0].interfaceid // empty'
}

create_item_if_missing() {
  local item_name="$1"
  local item_key="$2"
  local response
  local item_id

  response="$(api_call_checked "{
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
    \"id\": 70
  }" "item.get (${item_key})")"

  item_id="$(echo "$response" | jq -r '.result[0].itemid // empty')"

  if [ -n "$item_id" ]; then
    log "Item ${item_key} already exists with ID ${item_id}."
    return 0
  fi

  log "Creating item ${item_name}..."

  response="$(api_call_checked "{
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
    \"id\": 71
  }" "item.create (${item_key})")"

  item_id="$(echo "$response" | jq -r '.result.itemids[0] // empty')"

  if [ -z "$item_id" ]; then
    error "Failed to create item ${item_key}."
    echo "$response"
    exit 1
  fi
}

create_trigger_if_missing() {
  local description="$1"
  local expression="$2"
  local response
  local trigger_id

  response="$(api_call_checked "{
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
    \"id\": 80
  }" "trigger.get (${description})")"

  trigger_id="$(echo "$response" | jq -r '.result[0].triggerid // empty')"

  if [ -n "$trigger_id" ]; then
    log "Trigger '${description}' already exists with ID ${trigger_id}."
    return 0
  fi

  log "Creating trigger ${description}..."

  response="$(api_call_checked "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"trigger.create\",
    \"params\": {
      \"description\": \"${description}\",
      \"expression\": \"${expression}\",
      \"priority\": 4
    },
    \"auth\": \"${AUTH_TOKEN}\",
    \"id\": 81
  }" "trigger.create (${description})")"

  trigger_id="$(echo "$response" | jq -r '.result.triggerids[0] // empty')"

  if [ -z "$trigger_id" ]; then
    error "Failed to create trigger '${description}'."
    echo "$response"
    exit 1
  fi
}

log "Authorizing in Zabbix API..."
AUTH_TOKEN="$(get_auth_token)"

if [ -z "$AUTH_TOKEN" ]; then
  error "Failed to get Zabbix auth token."
  exit 1
fi

log "Auth successful."

delete_default_zabbix_host_if_exists

log "Getting template ID for '${TEMPLATE_NAME}'..."
TEMPLATE_ID="$(get_template_id_by_name "${TEMPLATE_NAME}")"

if [ -z "$TEMPLATE_ID" ]; then
  error "Could not find template '${TEMPLATE_NAME}'."
  exit 1
fi

log "Getting or creating host group '${HOST_GROUP_NAME}'..."
GROUP_ID="$(get_or_create_group_id "${HOST_GROUP_NAME}")"

if [ -z "$GROUP_ID" ]; then
  error "Could not get/create host group '${HOST_GROUP_NAME}'."
  exit 1
fi

HOST_ID="$(create_host_if_missing)"

if ! [[ "$HOST_ID" =~ ^[0-9]+$ ]]; then
  error "HOST_ID is invalid: $HOST_ID"
  exit 1
fi

if [ -z "$HOST_ID" ]; then
  error "Failed to get/create host '${HOST_NAME}'."
  exit 1
fi

log "Getting interface ID for host ${HOST_NAME}..."
INTERFACE_ID="$(get_host_interface_id "${HOST_ID}")"

if [ -z "$INTERFACE_ID" ]; then
  error "Failed to get host interface ID."
  exit 1
fi

log "Host interface ID: ${INTERFACE_ID}"

create_item_if_missing "Jenkins status" "service.jenkins"
create_item_if_missing "Vault status" "service.vault"
create_item_if_missing "Zabbix web status" "service.zabbix_web"
create_item_if_missing "Zabbix server status" "service.zabbix_server"

create_trigger_if_missing "Jenkins is down" "last(/${HOST_NAME}/service.jenkins)=0"
create_trigger_if_missing "Vault is down" "last(/${HOST_NAME}/service.vault)=0"
create_trigger_if_missing "Zabbix web is down" "last(/${HOST_NAME}/service.zabbix_web)=0"
create_trigger_if_missing "Zabbix server is down" "last(/${HOST_NAME}/service.zabbix_server)=0"

log "Zabbix API configuration completed successfully."