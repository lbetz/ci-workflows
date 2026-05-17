#!/usr/bin/env bash
set -euo pipefail

# Libs laden
source /workspace/.ci-workflows/hooks/lib/distro.sh
source /workspace/.ci-workflows/hooks/lib/common.sh || true

log "Starting rpmbuild in container – distro: $ID ($ID_LIKE)"

# ---------------------------------------------------------------------------
# PRE-BUILD HOOK
# ---------------------------------------------------------------------------
if [ -f /workspace/.ci-workflows/hooks/pre_build_in_container.sh ]; then
  log "Running global pre_build_in_container hook..."
  bash /workspace/.ci-workflows/hooks/pre_build_in_container.sh
fi

# ---------------------------------------------------------------------------
# PRE-BUILD HOOK (Projekt)
# ---------------------------------------------------------------------------
if [ -f /workspace/.github/hooks/pre_build.sh ]; then
  log "Running project pre_build hook..."
  bash /workspace/.github/hooks/pre_build.sh
fi

# ---------------------------------------------------------------------------
# BUILD
# ---------------------------------------------------------------------------
mkdir -p /workspace/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

SPECFILE=$(ls /workspace/*.spec | head -n1)
cp -v "$SPECFILE" /workspace/rpmbuild/SPECS/

log "Downloading sources from SPEC via spectool..."
spectool -g -R \
  --define "_topdir /workspace/rpmbuild" \
  /workspace/rpmbuild/SPECS/*.spec

log "Running rpmbuild..."
rpmbuild \
  --define "_topdir /workspace/rpmbuild" \
  -ba /workspace/rpmbuild/SPECS/*.spec

# ---------------------------------------------------------------------------
# POST-BUILD HOOK (Projekt)
# ---------------------------------------------------------------------------
if [ -f /workspace/.github/hooks/post_build.sh ]; then
  log "Running project post_build hook..."
  bash /workspace/.github/hooks/post_build.sh
fi

log "Build container script finished."

