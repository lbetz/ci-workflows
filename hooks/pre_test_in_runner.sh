#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/distro.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh" || true

log "Preparing runner for test..."

# hier nur Dinge, die der Runner braucht (z.B. docker, jq etc.)
# Beispiel:
if is_debian_like; then
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends jq
fi
