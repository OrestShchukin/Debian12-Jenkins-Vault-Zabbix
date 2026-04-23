#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Generating self-signed TLS certificates..."

CERT_DIR="/opt/devops-stack/docker/nginx/certs"
CERT_KEY="${CERT_DIR}/selfsigned.key"
CERT_CRT="${CERT_DIR}/selfsigned.crt"

mkdir -p "$CERT_DIR"

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout "$CERT_KEY" \
  -out "$CERT_CRT" \
  -subj "/C=UA/ST=Lvivska Oblast/L=Lviv/O=DevOpsStack/OU=IT/CN=jenkins.local" \
  -addext "subjectAltName=DNS:jenkins.local,DNS:zabbix.local,DNS:vault.local"

ls -lah "$CERT_DIR"

chmod 600 "$CERT_KEY"
chmod 644 "$CERT_CRT"

echo "[INFO] Self-signed TLS certificates generated."