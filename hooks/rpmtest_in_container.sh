#!/usr/bin/env bash
set -euo pipefail

source /workspace/.ci-workflows/hooks/lib/distro.sh
source /workspace/.ci-workflows/hooks/lib/common.sh || true

log "Starting rpm test in container – distro: $ID ($ID_LIKE)"

# ---------------------------------------------------------------------------
# PRE-TEST HOOK
# ---------------------------------------------------------------------------
if [ -f /workspace/.ci-workflows/hooks/pre_test_in_container.sh ]; then
  log "Running global pre_test_in_container hook..."
  bash /workspace/.ci-workflows/hooks/pre_test_in_container.sh
fi

# ---------------------------------------------------------------------------
# PRE-TEST HOOK (Projekt)
# ---------------------------------------------------------------------------
if [ -f /workspace/.github/hooks/pre_test.sh ]; then
  log "Running project pre_test hook..."
  bash /workspace/.github/hooks/pre_test.sh
fi

# ---------------------------------------------------------------------------
# RPM INSTALLATION
# ---------------------------------------------------------------------------
log "Installing built RPMs..."

RPM_DIR="/workspace/rpms"

if ! compgen -G "$RPM_DIR/*.rpm" > /dev/null; then
  echo "❌ Keine RPMs im Test-Container gefunden!" >&2
  exit 1
fi

case "$ID" in
  rhel|centos|almalinux|rocky|fedora)
    dnf install -y "$RPM_DIR"/*.rpm
    ;;
  debian|ubuntu)
    echo "❌ Debian/Ubuntu können keine RPMs installieren." >&2
    exit 1
    ;;
  *)
    echo "❌ Unbekannte Distro: $ID" >&2
    exit 1
    ;;
esac

log "RPM installation successful."

# ---------------------------------------------------------------------------
# POST-TEST HOOK (Projekt)
# ---------------------------------------------------------------------------
if [ -f /workspace/.github/hooks/post_test.sh ]; then
  log "Running project post_test hook..."
  bash /workspace/.github/hooks/post_test.sh
fi

log "Test container script finished."

