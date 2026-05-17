#!/usr/bin/env bash
set -euo pipefail

source /workspace/.ci-workflows/hooks/lib/distro.sh
source /workspace/.ci-workflows/hooks/lib/common.sh || true

log "Running global pre-build container setup for distro: $ID ($ID_LIKE)"

if is_el || is_fedora; then
  dnf install -y --allowerasing \
    rpm-build \
    rpmdevtools \
    redhat-rpm-config \
    make \
    gcc \
    gcc-c++ \
    tar \
    gzip \
    bzip2 \
    patch \
    which \
    git \
    wget \
    dnf-plugins-core
  dnf clean all
elif is_fedora; then
  dnf groupinstall -y "Development Tools"
  dnf install -y rpm-build rpmdevtools redhat-rpm-config
  dnf clean all
elif is_debian || is_ubuntu; then
  apt-get update -y
  apt-get install -y build-essential rpm git tar gzip
else
  echo "❌ Unsupported distro for RPM build: $ID"
  exit 1
fi

