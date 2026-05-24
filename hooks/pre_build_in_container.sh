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
  apt-get install -y \
    build-essential \
    git \
    tar \
    gzip \
    devscripts \
    debhelper \
    fakeroot \
    curl \
    rsync \
    ca-certificates

  log "DEBUG: Searching for packaging debian directory..."
  find / -maxdepth 5 -type d -name debian 2>/dev/null | grep -v build-src

  log "Running uscan..."
  uscan --verbose --download-current-version --force-download

  PKG=$(dpkg-parsechangelog -S Source)
  VER_FULL=$(dpkg-parsechangelog -S Version)
  VER=${VER_FULL%-*}

  ORIG="../${PKG}_${VER}.orig.tar.xz"

  log "Extracting upstream source..."
  rm -rf ../build-src
  mkdir ../build-src
  tar --extract --xz --file "$ORIG" --directory ../build-src

  log "Copying orig tarball into /workspace..."
  cp "$ORIG" /workspace/

  log "Detecting upstream directory..."
  UPSTREAM_DIR=$(find ../build-src -mindepth 1 -maxdepth 1 -type d | head -n1)
  log "Upstream directory is: $UPSTREAM_DIR"

  log "Removing upstream debian/ directory..."
  rm -rf "$UPSTREAM_DIR/debian"

  log "Copying upstream code into /workspace..."
  mkdir -p /workspace/upstream
  rsync -a "$UPSTREAM_DIR"/ /workspace/upstream/

  log "Copying packaging debian/ into upstream/"
  cp -a /workspace/debian /workspace/upstream/
else
  echo "❌ Unsupported distro for RPM build: $ID"
  exit 1
fi

log "Global pre-build container completed successfully."
