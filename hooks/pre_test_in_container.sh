#!/usr/bin/env bash
set -euo pipefail

source /workspace/.ci-workflows/hooks/lib/distro.sh
source /workspace/.ci-workflows/hooks/lib/common.sh || true

log "Running global pre-test container setup for distro: $ID ($ID_LIKE)"

# ---------------------------------------------------------------------------
# RPM-BASED DISTROS
# ---------------------------------------------------------------------------
if is_el || is_fedora; then
  dnf install -y \
    python3 \
    python3-pip \
    diffutils \
    systemd \
    which \
    tar \
    gzip

  dnf clean all
  log "Global pre-test container completed successfully for RPM."
  exit 0
fi

# ---------------------------------------------------------------------------
# DEB-BASED DISTROS
# ---------------------------------------------------------------------------
if is_debian || is_ubuntu; then
  log "Installing test dependencies for DEB-based distro..."

  apt-get update
  apt-get install -y \
    python3 \
    python3-pip \
    diffutils \
    systemd \
    which \
    tar \
    gzip

  apt-get clean
  log "Global pre-test container completed successfully for DEB."
  exit 0
fi

echo "❌ Unsupported distro for RPM test: $ID"
exit 1
