#!/usr/bin/env bash
set -e
source "$(dirname "${BASH_SOURCE[0]}")/lib/distro.sh"

echo "[HOOK] Installing build prerequisites..."

if is_el; then
  sudo dnf install -y \
    rpm-build \
    rpmdevtools \
    redhat-rpm-config \
    make \
    gcc \
    gcc-c++ \
    git \
    tar \
    gzip \
    bzip2 \
    patch \
    which
elif is_fedora; then
  sudo dnf groupinstall -y "Development Tools"
  sudo dnf install -y rpm-build rpmdevtools redhat-rpm-config
elif is_debian || is_ubuntu; then
  sudo apt-get update -y
  sudo apt-get install -y build-essential rpm git tar gzip
fi

# Optional: Build-Verzeichnisse einrichten
mkdir -p BUILD BUILDROOT RPMS SOURCES SPECS SRPMS
