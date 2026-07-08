#!/usr/bin/env bash
set -euo pipefail
trap 'echo "[ERROR] Test failed at line $LINENO" >&2' ERR

source /workspace/.ci-workflows/hooks/lib/distro.sh
source /workspace/.ci-workflows/hooks/lib/common.sh || true

log "Starting rpm test in container – distro: $ID ($ID_LIKE), format: $PACKAGE_FORMAT"

# ---------------------------------------------------------------------------
# 1. GLOBAL PRE-TEST HOOK
# ---------------------------------------------------------------------------
if [ -f /workspace/.ci-workflows/hooks/pre_test_in_container.sh ]; then
  log "Running global pre_test_in_container hook..."
  bash /workspace/.ci-workflows/hooks/pre_test_in_container.sh
fi

# ---------------------------------------------------------------------------
# 2. PROJECT PRE-TEST HOOK
# ---------------------------------------------------------------------------
if [ -f /workspace/.github/hooks/pre_test.sh ]; then
  log "Running project pre_test hook..."
  bash /workspace/.github/hooks/pre_test.sh
fi

# ---------------------------------------------------------------------------
# 3. DETECT PACKAGE FORMAT
# ---------------------------------------------------------------------------
PKG_DIR="/workspace/pkgs"

if ls "$PKG_DIR"/*.rpm >/dev/null 2>&1; then
  PACKAGE_FORMAT="rpm"
elif ls "$PKG_DIR"/*.deb >/dev/null 2>&1; then
  PACKAGE_FORMAT="deb"
else
  echo "❌ No RPM or DEB packages found in $PKG_DIR" >&2
  exit 1
fi

log "Detected package format: $PACKAGE_FORMAT"

# ---------------------------------------------------------------------------
# 4. INSTALL PACKAGE
# ---------------------------------------------------------------------------
if [[ "$PACKAGE_FORMAT" == "rpm" ]]; then
log "Installing built RPMs..."

  case "$ID" in
    rhel|centos|almalinux|rocky|fedora)
      BINARIES=()
      for pkg in "$PKG_DIR"/*.rpm; do
        case "$pkg" in
          *.src.rpm) continue ;;   # SRPM überspringen
          *) BINARIES+=("$pkg") ;;
        esac
      done

      if (( ${#BINARIES[@]} == 0 )); then
        echo "❌ No binary RPMs found in $PKG_DIR" >&2
        exit 1
      fi

      if ! dnf install -y "${BINARIES[@]}"; then
        echo "❌ RPM installation failed – missing dependencies?" >&2
        exit 1
      fi
      ;;
    *)
      echo "❌ Unsupported distro for RPM testing: $ID" >&2
      exit 1
      ;;
  esac

  log "RPM installation successful."
fi

if [[ "$PACKAGE_FORMAT" == "deb" ]]; then
  log "Installing DEB packages..."

  DEBS=()
  for pkg in "$PKG_DIR"/*.deb; do
    [[ -e "$pkg" ]] || continue
    DEBS+=("$pkg")
  done

  if (( ${#DEBS[@]} == 0 )); then
    echo "❌ No DEB packages found in $PKG_DIR" >&2
    exit 1
  fi

  case "$ID" in
    debian|ubuntu)
      apt-get update
      apt-get install -y "${DEBS[@]}"
      ;;
    *)
      echo "❌ Unsupported distro for DEB testing: $ID" >&2
      exit 1
      ;;
  esac

  log "DEB installation successful."
fi

# ---------------------------------------------------------------------------
# 4. SMOKE TESTS
# ---------------------------------------------------------------------------
if [ -f /workspace/.github/hooks/smoke.sh ]; then
  log "Running project smoke tests..."
  bash /workspace/.github/hooks/smoke.sh
else
  log "No smoke.sh found – skipping smoke tests."
fi

# ---------------------------------------------------------------------------
# 5. PROJECT POST-TEST HOOK
# ---------------------------------------------------------------------------
if [ -f /workspace/.github/hooks/post_test.sh ]; then
  log "Running project post_test hook..."
  bash /workspace/.github/hooks/post_test.sh
fi

log "Test container script finished."
