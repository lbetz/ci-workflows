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

runner_user="${SUDO_USER:-${USER:-}}"

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

install_base_packages() {
  log "Installing base packages"
  apt-get update
  apt-get install -y \
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
    log "Installing Docker"
    apt-get install -y docker.io
  fi

  systemctl enable --now docker

  if id -nG "$runner_user" | grep -qw docker; then
    log "User '$runner_user' is already in docker group"
  else
    log "Adding user '$runner_user' to docker group"
    usermod -aG docker "$runner_user"
  fi
}

configure_sudoers() {
  local sudoers_file="/etc/sudoers.d/90-github-runner"

  if [[ -f "$sudoers_file" ]] && grep -Fqx "$runner_user ALL=(ALL) NOPASSWD:ALL" "$sudoers_file"; then
    log "Passwordless sudo already configured for '$runner_user'"
    return 0
  fi

  log "Configuring passwordless sudo for '$runner_user'"
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$runner_user" > "$sudoers_file"
  chmod 440 "$sudoers_file"
  visudo -cf "$sudoers_file"
}

install_qemu() {
  log "Installing QEMU and binfmt support"
  apt-get install -y qemu-user-static binfmt-support
  systemctl enable --now binfmt-support || true
  update-binfmts --enable || true

  if command -v docker >/dev/null 2>&1; then
    log "Registering binfmt handlers via Docker"
    docker run --privileged --rm tonistiigi/binfmt --install all
  fi
}

install_signing_tools() {
  log "Installing signing helpers"

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
