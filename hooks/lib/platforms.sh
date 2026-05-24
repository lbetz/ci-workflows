#!/usr/bin/env bash
set -euo pipefail

# map_arch_to_platform <arch>
# Echoes the docker platform string or returns non-zero on unsupported arch.
map_arch_to_platform() {
  local arch="$1"
  case "$arch" in
    x86_64)  printf '%s' "linux/amd64" ;;
    aarch64) printf '%s' "linux/arm64" ;;
    ppc64le) printf '%s' "linux/ppc64le" ;;
    s390x)   printf '%s' "linux/s390x" ;;
    *) return 1 ;;
  esac
}

