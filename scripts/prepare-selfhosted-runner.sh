#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This bootstrap script only supports Linux runners." >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "/etc/os-release not found; cannot determine distribution." >&2
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

runner_user="${RUNNER_USER:-${SUDO_USER:-${USER:-}}}"

if [[ -z "$runner_user" ]]; then
  echo "Could not determine the runner user." >&2
  exit 1
fi

if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" && "${ID_LIKE:-}" != *debian* ]]; then
  echo "This bootstrap script expects Ubuntu or Debian. Detected ID='${ID:-unknown}' ID_LIKE='${ID_LIKE:-}'." >&2
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script with sudo or as root." >&2
  exit 1
fi

log() {
  printf '[bootstrap] %s\n' "$*"
}

apt_install_if_missing() {
  local missing=()
  local pkg

  for pkg in "$@"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if (( ${#missing[@]} == 0 )); then
    log "Packages already present: $*"
    return 0
  fi

  log "Installing missing packages: ${missing[*]}"
  apt-get install -y "${missing[@]}"
}

install_base_packages() {
  log "Ensuring base packages"
  apt-get update
  apt_install_if_missing \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    rpm \
    software-properties-common \
    sudo
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed"
  else
    log "Installing Docker from distro packages"
    apt_install_if_missing docker.io
  fi

  if docker info >/dev/null 2>&1; then
    log "Docker daemon already reachable"
  elif command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q '^docker\.service'; then
    log "Starting docker.service"
    systemctl enable --now docker
  else
    log "docker command found, but daemon is not reachable and docker.service was not detected"
  fi

  if id -nG "$runner_user" | grep -qw docker; then
    log "User '$runner_user' is already in docker group"
  else
    log "Adding user '$runner_user' to docker group"
    usermod -aG docker "$runner_user"
  fi
}

configure_sudoers() {
  local sudoers_file="/etc/sudoers.d/90-github-runner"
  local sudoers_line="$runner_user ALL=(ALL) NOPASSWD:ALL"

  if [[ -f "$sudoers_file" ]] && grep -Fqx "$sudoers_line" "$sudoers_file"; then
    log "Passwordless sudo already configured for '$runner_user'"
    return 0
  fi

  log "Configuring passwordless sudo for '$runner_user'"

  if [[ -f "$sudoers_file" ]]; then
    printf '%s\n' "$sudoers_line" >> "$sudoers_file"
  else
    printf '%s\n' "$sudoers_line" > "$sudoers_file"
  fi

  chmod 440 "$sudoers_file"
  visudo -cf "$sudoers_file"
}

install_qemu() {
  log "Ensuring QEMU and binfmt support"
  apt_install_if_missing qemu-user-static binfmt-support

  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q '^binfmt-support\.service'; then
    systemctl enable --now binfmt-support || true
  fi

  update-binfmts --enable || true

  if command -v docker >/dev/null 2>&1; then
    log "Registering binfmt handlers via Docker"
    docker run --privileged --rm tonistiigi/binfmt --install all
  fi
}

install_signing_tools() {
  log "Ensuring signing helpers"

  if command -v dpkg-sig >/dev/null 2>&1 || command -v debsigs >/dev/null 2>&1; then
    log "DEB signing helper already available"
    return 0
  fi

  if apt-get install -y dpkg-sig; then
    log "Installed dpkg-sig"
  else
    log "dpkg-sig unavailable, falling back to debsigs"
    apt-get install -y debsigs
  fi
}

print_post_steps() {
  cat <<EOF

Bootstrap complete.

Next steps:
1. Start a new login session for user '$runner_user' so docker group membership is active.
2. Verify runner access with:
   sudo -n true
   docker info
   python3 -m pip --version
   test -d /proc/sys/fs/binfmt_misc && cat /proc/sys/fs/binfmt_misc/status
   command -v gpg
   command -v rpmsign
   command -v dpkg-sig || command -v debsigs
3. Ensure outbound network access to GitHub, PyPI, and your Pulp instance.
4. Set the required GitHub secrets in the calling repository.

Required GitHub secrets:
- PACKAGE_SIGNING_PRIVATE_KEY
- PACKAGE_SIGNING_KEY_ID
- PACKAGE_SIGNING_PASSPHRASE
- PULP_URL
- PULP_USERNAME
- PULP_PASSWORD
EOF
}

install_base_packages
install_docker
configure_sudoers
install_qemu
install_signing_tools
print_post_steps
