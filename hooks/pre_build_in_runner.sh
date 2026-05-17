#!/usr/bin/env bash
set -euo pipefail

# zentrale Libs laden
source "$(dirname "${BASH_SOURCE[0]}")/lib/distro.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh" || true

log "Preparing runner for build..."

if is_debian || is_ubuntu; then
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends rpm createrepo-c
fi

chmod +x "$(dirname "${BASH_SOURCE[0]}")"/*.sh        2>/dev/null || true
chmod +x "$(dirname "${BASH_SOURCE[0]}")/lib/"*.sh    2>/dev/null || true
chmod +x .github/hooks/*.sh                           2>/dev/null || true

