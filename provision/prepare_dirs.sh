#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Preparing directories..."

mkdir -p /opt/devops-test/docker
rm -rf /opt/devops-test/docker/*

cp -r /vagrant/docker/* /opt/devops-test/docker/

chown -R vagrant:vagrant /opt/devops-test

echo "[INFO] Directories ready. Directory Changed to /opt"



