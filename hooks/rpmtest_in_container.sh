#!/usr/bin/env bash
set -euo pipefail
trap 'echo "[ERROR] Test failed at line $LINENO" >&2' ERR

source /workspace/.ci-workflows/hooks/lib/distro.sh
source /workspace/.ci-workflows/hooks/lib/common.sh || true

log "Starting rpm test in container – distro: $ID ($ID_LIKE)"

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
# 3. INSTALL BUILT RPMs
# ---------------------------------------------------------------------------
log "Installing built RPMs..."

RPM_DIR="/workspace/rpms"

case "$ID" in
  rhel|centos|almalinux|rocky|fedora)
    BINARIES=()
    for pkg in "$RPM_DIR"/*.rpm; do
      case "$pkg" in
        *.src.rpm) continue ;;   # SRPM überspringen
        *) BINARIES+=("$pkg") ;;
      esac
    done
    
    if (( ${#BINARIES[@]} == 0 )); then
      echo "❌ No binary RPMs found in $RPM_DIR" >&2
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

