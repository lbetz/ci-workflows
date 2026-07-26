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
  if grep -q 'rubygems\.org/api/v1/versions' /workspace/debian/watch 2>/dev/null; then
    # For Rubygems API watch files we only query version metadata here and keep CI logs concise.
    uscan_log="$(mktemp)"
    if ! uscan --report >"$uscan_log" 2>&1; then
      log "uscan report returned non-zero for Rubygems watch (continuing with fallback)."
    fi

    if grep -Eiq 'uscan (warn|error):|Newest version' "$uscan_log"; then
      grep -Ei 'uscan (warn|error):|Newest version' "$uscan_log" || true
    fi
    rm -f "$uscan_log"
  elif ! uscan --download-current-version --force-download; then
    log "uscan did not download an upstream archive; trying fallback handling."
  fi

  PKG=$(dpkg-parsechangelog -S Source)
  VER_FULL=$(dpkg-parsechangelog -S Version)
  VER=${VER_FULL%-*}

  ORIG="../${PKG}_${VER}.orig.tar.xz"

  rm -rf /workspace/upstream

  if [[ -f "$ORIG" ]]; then
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
    if grep -q 'rubygems\.org' /workspace/debian/watch 2>/dev/null; then
      GEM_NAME="$(sed -n 's#.*/versions/\([^/]*\)/latest\.json.*#\1#p' /workspace/debian/watch | head -n1)"
      GEM_NAME="${GEM_NAME:-ansi}"
      GEM_FILE="${GEM_NAME}-${VER}.gem"
      GEM_URL="https://rubygems.org/downloads/${GEM_FILE}"

      log "No orig.tar produced; using Rubygems fallback for ${GEM_FILE}"
      curl -fL --retry 3 -o "/workspace/${GEM_FILE}" "${GEM_URL}"

      mkdir -p /workspace/upstream
      rsync -a \
        --exclude '.git/' \
        --exclude '.github/' \
        --exclude 'upstream/' \
        --exclude 'rpmbuild/' \
        /workspace/ /workspace/upstream/
    else
      echo "❌ uscan did not provide ../${PKG}_${VER}.orig.tar.xz and no Rubygems fallback matched." >&2
      exit 1
    fi
  fi

  log "Applying distro-specific Debian version suffix..."
  cd /workspace/upstream
  CURRENT_VERSION="$(dpkg-parsechangelog -S Version)"
  DIST_SUFFIX="${ID}${VERSION_ID//[^0-9A-Za-z]/}"

  if [[ "$CURRENT_VERSION" == *"+$DIST_SUFFIX" ]]; then
    log "Debian package version already contains suffix: $CURRENT_VERSION"
  else
    NEW_VERSION="${CURRENT_VERSION}+${DIST_SUFFIX}"
    MAINTAINER="$(dpkg-parsechangelog -S Maintainer)"
    export DEBFULLNAME="${MAINTAINER% <*}"
    export DEBEMAIL="${MAINTAINER##*<}"
    DEBEMAIL="${DEBEMAIL%>}"
    export DEBEMAIL

    dch --distribution stable --force-distribution --newversion "$NEW_VERSION" \
      "CI rebuild for ${ID} ${VERSION_ID}." >/dev/null

    log "Debian package version set to: $(dpkg-parsechangelog -S Version)"
  fi
else
  echo "❌ Unsupported distro for RPM build: $ID"
  exit 1
fi

log "Global pre-build container completed successfully."
