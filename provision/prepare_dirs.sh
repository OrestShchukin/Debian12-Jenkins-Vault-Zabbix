#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Installing Docker..."

install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.asc ]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
fi

ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"

echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  ${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

usermod -aG docker vagrant || true

docker --version
docker compose version

echo "[INFO] Docker installed successfully."

mkdir -p /opt/devops-test
mkdir -p /opt/devops-test/docker
cp -r /vagrant/docker/* /opt/devops-test/docker/

echo "[INFO] Directory /opt/devops-test/docker created"

cd /opt/devops-test/docker
docker compose up -d


