#!/usr/bin/env bash
set -euo pipefail

get_container_image() {
  local distro="$1"

  case "$distro" in
    el8)      echo "almalinux:8" ;;
    el9)      echo "almalinux:9" ;;
    el10)     echo "almalinux:10" ;;
    fedora43) echo "fedora:43" ;;
    fedora44) echo "fedora:44" ;;
    *)        echo "almalinux:9" ;;
  esac
}

