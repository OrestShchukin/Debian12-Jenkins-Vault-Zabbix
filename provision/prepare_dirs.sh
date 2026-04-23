#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Preparing directories..."

mkdir -p /opt/devops-stack/docker
rm -rf /opt/devops-stack/docker/*

cp -r /vagrant/docker/* /opt/devops-stack/docker/

chown -R vagrant:vagrant /opt/devops-stack

echo "[INFO] Directories ready. Directory Changed to /opt"



