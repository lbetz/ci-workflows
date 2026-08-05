#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/distro.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh" || true

log "Preparing runner for test..."

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

configure_ubuntu_mirror() {
  local mirror_root="${APT_UBUNTU_MIRROR_ROOT:-}"
  local suite=""

  if [[ -z "${mirror_root}" ]]; then
    return 0
  fi

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${ID:-}" != "ubuntu" ]]; then
      log "APT_UBUNTU_MIRROR_ROOT is set, but runner is not Ubuntu; skipping mirror rewrite"
      return 0
    fi
    suite="${VERSION_CODENAME:-}"
  fi

  if [[ -z "${suite}" ]]; then
    log "Ubuntu mirror rewrite requested but VERSION_CODENAME is unavailable"
    return 1
  fi

  mirror_root="${mirror_root%/}"
  log "Rewriting Ubuntu apt sources to ${mirror_root}"

  sudo install -d -m 0755 /etc/apt/sources.list.d
  if sudo test -f /etc/apt/sources.list && ! sudo test -f /etc/apt/sources.list.orig; then
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.orig
  fi
  if sudo test -f /etc/apt/sources.list.d/ubuntu.sources && ! sudo test -f /etc/apt/sources.list.d/ubuntu.sources.orig; then
    sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.orig
  fi
  if sudo test -f /etc/apt/sources.list.d/ubuntu.sources && ! sudo test -f /etc/apt/sources.list.d/ubuntu.sources.disabled; then
    sudo mv /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.disabled
  fi
  printf '' | sudo tee /etc/apt/sources.list >/dev/null
  cat <<EOF2 | sudo tee /etc/apt/sources.list.d/pulp-ubuntu-mirror.sources >/dev/null
Types: deb
URIs: ${mirror_root}/ubuntu-base
Suites: ${suite}
Components: main restricted universe multiverse

Types: deb
URIs: ${mirror_root}/ubuntu-updates-base
Suites: ${suite}-updates
Components: main restricted universe multiverse

Types: deb
URIs: ${mirror_root}/ubuntu-backports-base
Suites: ${suite}-backports
Components: main restricted universe multiverse

Types: deb
URIs: ${mirror_root}/ubuntu-security-base
Suites: ${suite}-security
Components: main restricted universe multiverse
EOF2
}

# hier nur Dinge, die der Runner braucht (z.B. docker, jq etc.)
# Beispiel:
if is_debian_like; then
  configure_ubuntu_mirror
  apt_safe update -y
  apt_safe install -y --no-install-recommends jq
fi
