#!/usr/bin/env bash
set -euo pipefail

source /workspace/.ci-workflows/hooks/lib/distro.sh
source /workspace/.ci-workflows/hooks/lib/common.sh || true

log "Running global pre-test container setup for distro: $ID ($ID_LIKE)"

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
else
  echo "❌ Unsupported distro for RPM test: $ID"
  exit 1
fi

log "Global pre-test container completed successfully."
