#!/usr/bin/env bash
set -euo pipefail

source /workspace/.ci-workflows/hooks/lib/distro.sh
source /workspace/.ci-workflows/hooks/lib/common.sh || true

log "Running global pre-build container setup for distro: $ID ($ID_LIKE)"

# ---------------------------------------------------------------------------
# Install build dependencies
# ---------------------------------------------------------------------------
if is_el || is_fedora; then
  log "Preparing rpmbuild environment..."
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

  mkdir -p /workspace/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
elif is_debian || is_ubuntu; then
  log "Preparing debian build environment..."
  apt-get update -y
  apt-get install -y build-essential rpm git tar gzip
else
  echo "❌ Unsupported distro for RPM build: $ID"
  exit 1
fi

log "Global pre-build container completed successfully."
