#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Starting bootstrap..."

chmod +x /vagrant/provision/*.sh

/vagrant/provision/install_packages.sh
/vagrant/provision/install_docker.sh
/vagrant/provision/prepare_dirs.sh

echo "[INFO] Bootstrap completed successfully."