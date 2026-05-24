#!/usr/bin/env bash
set -euo pipefail

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "⚠️ /etc/os-release nicht gefunden – Standardwerte setzen"
  ID="unknown"
  ID_LIKE=""
  VERSION_ID="0"
fi

# Fedora hat KEIN ID_LIKE → hier setzen wir es sicher
ID="${ID,,}"
ID_LIKE="${ID_LIKE:-}"        # verhindert "unbound variable"
VERSION_ID="${VERSION_ID:-0}" # verhindert "unbound variable"

# RELEASE = Major-Version
RELEASE="${VERSION_ID%%.*}"

is_el() {
  [[ "$ID" == *"rhel"* ]] \
    || [[ "$ID" == "almalinux" ]] \
    || [[ "$ID" == "rocky" ]] \
    || [[ "$ID_LIKE" == *"rhel"* ]]
}

is_fedora()  { [[ "$ID" == "fedora" ]]; }
is_debian()  { [[ "$ID" == "debian" ]] || [[ "$ID_LIKE" == *"debian"* ]]; }
is_ubuntu()  { [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"ubuntu"* ]]; }
is_suse()    { [[ "$ID" == opensuse* ]] || [[ "$ID_LIKE" == *"suse"* ]]; }
is_alpine()  { [[ "$ID" == "alpine" ]]; }
is_arch()    { [[ "$ID" == "arch" ]] || [[ "$ID_LIKE" == *"arch"* ]]; }

is_rpm_based() {
  is_el || is_fedora || is_suse
}

is_deb_based() {
  is_debian || is_ubuntu
}

# Export für Hooks
if is_rpm_based; then
  PACKAGE_FORMAT="rpm"
elif is_deb_based; then
  PACKAGE_FORMAT="deb"
else
  PACKAGE_FORMAT="unknown"
fi
