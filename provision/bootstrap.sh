#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Starting bootstrap..."

chmod +x /vagrant/provision/*.sh

/vagrant/provision/install_packages.sh
/vagrant/provision/install_docker.sh
/vagrant/provision/prepare_dirs.sh

echo "[INFO] Starting Docker Compose services..."
docker compose up -d --build

/vagrant/provision/install_zabbix_agent.sh
/vagrant/provision/configure_zabbix_agent.sh

/vagrant/provision/wait_for_zabbix.sh
/vagrant/provision/configure_zabbix_api.sh

echo "[INFO] Bootstrap completed successfully."