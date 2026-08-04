#!/usr/bin/env bash
set -euo pipefail

# zentrale Libs laden
source "$(dirname "${BASH_SOURCE[0]}")/lib/distro.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh" || true

log "Preparing runner for build..."

# Robust apt wrapper to avoid long hangs on mirror/network glitches.
apt_safe() {
  local apt_timeout="${APT_TIMEOUT_SECONDS:-300}"
  local max_attempts="${APT_MAX_ATTEMPTS:-3}"
  local attempt=1
  local sleep_seconds=10

  local -a apt_opts=(
    -o Acquire::Retries=3
    -o Acquire::http::Timeout=30
    -o Acquire::https::Timeout=30
    -o Acquire::ForceIPv4=true
    -o Dpkg::Lock::Timeout=60
  )

  while :; do
    log "apt attempt ${attempt}/${max_attempts}: apt-get $*"

    if command -v timeout >/dev/null 2>&1; then
      if timeout "${apt_timeout}" sudo -n apt-get "${apt_opts[@]}" "$@"; then
        return 0
      fi
    else
      if sudo -n apt-get "${apt_opts[@]}" "$@"; then
        return 0
      fi
    fi

    if (( attempt >= max_attempts )); then
      log "apt failed permanently after ${attempt} attempts: apt-get $*"
      return 1
    fi

    log "apt attempt ${attempt} failed, retrying in ${sleep_seconds}s"
    sleep "${sleep_seconds}"
    attempt=$((attempt + 1))
  done
}

if is_debian_like; then
  apt_safe update -y
  apt_safe install -y --no-install-recommends \
    rpm \
    createrepo-c \
    ca-certificates
fi

chmod +x "$(dirname "${BASH_SOURCE[0]}")"/*.sh        2>/dev/null || true
chmod +x "$(dirname "${BASH_SOURCE[0]}")/lib/"*.sh    2>/dev/null || true
chmod +x .github/hooks/*.sh                           2>/dev/null || true
