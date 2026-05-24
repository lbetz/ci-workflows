#!/usr/bin/env bash
set -euo pipefail
trap 'echo "[ERROR] Build failed at line $LINENO" >&2' ERR

source /workspace/.ci-workflows/hooks/lib/distro.sh
source /workspace/.ci-workflows/hooks/lib/common.sh || true

log "Starting rpmbuild in container – distro: $ID ($ID_LIKE), format: $PACKAGE_FORMAT"

# ---------------------------------------------------------------------------
# 1. GLOBAL PRE-BUILD HOOK
# ---------------------------------------------------------------------------
if [ -f /workspace/.ci-workflows/hooks/pre_build_in_container.sh ]; then
  log "Running global pre_build_in_container hook..."
  bash /workspace/.ci-workflows/hooks/pre_build_in_container.sh
fi

# ---------------------------------------------------------------------------
# 2. PROJECT PRE-BUILD HOOK
# ---------------------------------------------------------------------------
if [ -f /workspace/.github/hooks/pre_build.sh ]; then
  log "Running project pre_build hook..."
  bash /workspace/.github/hooks/pre_build.sh
fi

# ---------------------------------------------------------------------------
# 3. FORMAT SWITCH
# ---------------------------------------------------------------------------
if [[ "$PACKAGE_FORMAT" == "rpm" ]]; then
  # ---------------------------------------------------------------------------
  # RPMBUILD DIRECTORY SETUP
  # ---------------------------------------------------------------------------
  log "Setting up rpmbuild directory structure..."
  TOPDIR="/workspace/rpmbuild"
  mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
  
  # ---------------------------------------------------------------------------
  # SPEC FILE VALIDATION
  # ---------------------------------------------------------------------------
  log "Searching for SPEC file in /workspace/SPECS..."
  
  shopt -s nullglob
  specs=(/workspace/*.spec)
  
  if (( ${#specs[@]} == 0 )); then
    echo "❌ No SPEC file found in /workspace/" >&2
    exit 1
  elif (( ${#specs[@]} > 1 )); then
    echo "❌ Multiple SPEC files found. Expected exactly one." >&2
    printf '%s\n' "${specs[@]}"
    exit 1
  fi
  
  SPECFILE="${specs[0]}"
  log "Using SPEC file: $SPECFILE"
  
  cp -v "$SPECFILE" "$TOPDIR/SPECS/"
  
  # ---------------------------------------------------------------------------
  # DOWNLOAD SOURCES VIA SPECTOOL
  # ---------------------------------------------------------------------------
  log "Downloading sources via spectool..."
  
  spectool -g -R \
    --define "_topdir $TOPDIR" \
    "$TOPDIR/SPECS/$(basename "$SPECFILE")"
  
  log "Downloaded sources:"
  ls -l "$TOPDIR/SOURCES"
  
  # ---------------------------------------------------------------------------
  # RUN RPMBUILD
  # ---------------------------------------------------------------------------
  log "Running rpmbuild..."
  
  rpmbuild \
    --define "_topdir $TOPDIR" \
    -ba "$TOPDIR/SPECS/$(basename "$SPECFILE")"
  
  log "rpmbuild completed successfully."
else
  # -------------------------------------------------------------------------
  # DEB BUILD
  # -------------------------------------------------------------------------
  log "DEB build selected – checking for debian/ directory..."

  if [ ! -d /workspace/debian ]; then
    echo "❌ No debian/ directory found in project root" >&2
    exit 1
  fi

  log "Running dpkg-buildpackage..."
  cd /workspace/upstream
  dpkg-buildpackage -us -uc

  log "dpkg-buildpackage completed successfully."
fi

# ---------------------------------------------------------------------------
# 7. PROJECT POST-BUILD HOOK
# ---------------------------------------------------------------------------
if [ -f /workspace/.github/hooks/post_build.sh ]; then
  log "Running project post_build hook..."
  bash /workspace/.github/hooks/post_build.sh
fi

log "Build container script finished."

