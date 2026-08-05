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

install_ubuntu_mirror_keyring() {
  local key_url="${APT_UBUNTU_MIRROR_KEY_URL:-https://packages.private.prefork.de/keys/prefork-packages.asc}"
  local key_tmp="${TMPDIR:-/tmp}/pulp-signing-public.asc"
  local keyring_path="/usr/share/keyrings/pulp-signing.gpg"

  if ! command -v curl >/dev/null 2>&1; then
    log "curl is required to install the Ubuntu mirror signing key"
    return 1
  fi

  if ! command -v gpg >/dev/null 2>&1; then
    log "gpg is required to install the Ubuntu mirror signing key"
    return 1
  fi

  log "Installing Ubuntu mirror signing key from ${key_url}"
  curl -fsSL "$key_url" -o "$key_tmp"
  sudo install -d -m 0755 /usr/share/keyrings
  sudo gpg --batch --dearmor -o "$keyring_path" "$key_tmp"
  sudo chmod 0644 "$keyring_path"
}

configure_ubuntu_mirror() {
  local mirror_root="${APT_UBUNTU_MIRROR_ROOT:-}"
  local suite=""
  local keyring_path="/usr/share/keyrings/pulp-signing.gpg"

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

  install_ubuntu_mirror_keyring
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
Signed-By: ${keyring_path}

Types: deb
URIs: ${mirror_root}/ubuntu-updates-base
Suites: ${suite}-updates
Components: main restricted universe multiverse
Signed-By: ${keyring_path}

Types: deb
URIs: ${mirror_root}/ubuntu-backports-base
Suites: ${suite}-backports
Components: main restricted universe multiverse
Signed-By: ${keyring_path}

Types: deb
URIs: ${mirror_root}/ubuntu-security-base
Suites: ${suite}-security
Components: main restricted universe multiverse
Signed-By: ${keyring_path}
EOF2
}

if is_debian_like; then
  configure_ubuntu_mirror
  apt_safe update -y
  apt_safe install -y --no-install-recommends \
    rpm \
    createrepo-c \
    ca-certificates
fi

chmod +x "$(dirname "${BASH_SOURCE[0]}")"/*.sh        2>/dev/null || true
chmod +x "$(dirname "${BASH_SOURCE[0]}")/lib/"*.sh    2>/dev/null || true
chmod +x .github/hooks/*.sh                           2>/dev/null || true
