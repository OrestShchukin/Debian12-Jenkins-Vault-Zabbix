#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Installing base packages..."

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common \
  jq \
  unzip \
  git \
  vim

echo "[INFO] Base packages installed."