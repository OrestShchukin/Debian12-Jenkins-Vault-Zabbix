#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Starting bootstrap..."

chmod +x /vagrant/provision/*.sh

/vagrant/provision/install_packages.sh
/vagrant/provision/install_docker.sh
/vagrant/provision/configure_network_stack.sh
/vagrant/provision/prepare_dirs.sh
/vagrant/provision/generate_self_signed_certs.sh
/vagrant/provision/create_systemd_unit.sh

echo "[INFO] Starting Docker Compose services..."

cd /opt/devops-stack/docker

for i in 1 2 3; do
  echo "[INFO] docker compose attempt ${i}/3"
  if docker compose up -d --build; then
    echo "[INFO] Docker Compose started successfully."
    break
  fi

  if [ "$i" -lt 3 ]; then
    echo "[WARN] Docker Compose failed. Retrying in 15s..."
    sleep 15
  else
    echo "[ERROR] Docker Compose failed after 3 attempts."
    exit 1
  fi
done

/vagrant/provision/install_zabbix_agent.sh
/vagrant/provision/configure_zabbix_agent.sh

/vagrant/provision/wait_for_zabbix.sh
/vagrant/provision/configure_zabbix_api.sh

echo "[INFO] Bootstrap completed successfully."