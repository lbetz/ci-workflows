#!/usr/bin/env bash
set -e
source "$(dirname "${BASH_SOURCE[0]}")/lib/distro.sh"

echo "[HOOK] Installing runtime/test dependencies..."

echo "[DEBUG] /etc/os-release content:"
cat /etc/os-release || true
echo "[DEBUG] Detected ID=$ID, ID_LIKE=$ID_LIKE"

if is_el; then
  # Zusätzliche Repos
  dnf install -y epel-release

  # Beispielabhängigkeiten (anpassen an dein Paket)
  dnf install -y \
    python3 \
    python3-pip \
    systemd \
    diffutils
elif is_fedora; then
  dnf install -y python3 python3-pip diffutils
elif is_debian || is_ubuntu; then
  apt-get update -y
  apt-get install -y python3 python3-pip diffutils
fi
