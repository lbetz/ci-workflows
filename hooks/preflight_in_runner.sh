#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

die() {
  echo "[PREFLIGHT] $*" >&2
  exit 1
}

need_command() {
  local cmd="$1"
  local hint="$2"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "Missing required command '$cmd'. $hint"
  fi
}

need_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    die "This workflow expects a Linux runner. Current OS: $(uname -s)"
  fi
}

need_root_or_passwordless_sudo() {
  if [[ "$(id -u)" == "0" ]]; then
    return 0
  fi

  need_command "sudo" "Install sudo or run the runner as root."
  if ! sudo -n true >/dev/null 2>&1; then
    die "Passwordless sudo is required because package installation runs non-interactively."
  fi
}

need_apt_get() {
  need_command "apt-get" "Use a Debian/Ubuntu runner or adapt the workflow hooks for your distribution."
}

need_docker() {
  need_command "docker" "Install Docker Engine/CLI on the runner."

  if ! docker info >/dev/null 2>&1; then
    die "Docker daemon is not reachable for the current runner user."
  fi
}

need_binfmt_support() {
  local arch="$1"

  case "$arch" in
    ""|x86_64)
      return 0
      ;;
  esac

  if [[ ! -d /proc/sys/fs/binfmt_misc ]]; then
    die "Cross-arch builds for '$arch' require binfmt_misc support on the runner host."
  fi

  if [[ -f /proc/sys/fs/binfmt_misc/status ]] && ! grep -q '^enabled$' /proc/sys/fs/binfmt_misc/status; then
    die "binfmt_misc exists but is not enabled; docker/setup-qemu-action will not be able to register emulators."
  fi
}

need_signing_secrets() {
  : "${PACKAGE_SIGNING_PRIVATE_KEY:?PACKAGE_SIGNING_PRIVATE_KEY secret is required when sign_packages=true}"
  : "${PACKAGE_SIGNING_KEY_ID:?PACKAGE_SIGNING_KEY_ID secret is required when sign_packages=true}"
  : "${PACKAGE_SIGNING_PASSPHRASE:?PACKAGE_SIGNING_PASSPHRASE secret is required when sign_packages=true}"
}

need_upload_secrets() {
  : "${PULP_URL:?PULP_URL secret is required for upload}"
  : "${PULP_USERNAME:?PULP_USERNAME secret is required for upload}"
  : "${PULP_PASSWORD:?PULP_PASSWORD secret is required for upload}"
}

need_python_and_pip() {
  need_command "python" "actions/setup-python must succeed before the upload tooling step."

  if ! python -m pip --version >/dev/null 2>&1; then
    die "Python is available but pip is not. Check the setup-python step and runner network access."
  fi
}

main() {
  local mode="${1:-}"
  local arch="${2:-}"

  case "$mode" in
    build|test)
      need_linux
      need_docker
      need_root_or_passwordless_sudo
      need_apt_get
      need_binfmt_support "$arch"
      ;;
    sign)
      need_linux
      need_root_or_passwordless_sudo
      need_apt_get
      need_signing_secrets
      ;;
    upload)
      need_linux
      need_python_and_pip
      need_upload_secrets
      ;;
    *)
      die "Usage: $0 <build|test|sign|upload> [arch]"
      ;;
  esac

  log "Preflight checks passed for mode '$mode'."
}

main "$@"