#!/usr/bin/env bash
set -euo pipefail

# Accept both legacy PULP_* and pulp-cli native PULP_CLI_* variables.
PULP_CLI_BASE_URL="${PULP_CLI_BASE_URL:-${PULP_URL:-}}"
PULP_CLI_USERNAME="${PULP_CLI_USERNAME:-${PULP_USERNAME:-}}"
PULP_CLI_PASSWORD="${PULP_CLI_PASSWORD:-${PULP_PASSWORD:-}}"

: "${PULP_CLI_BASE_URL:?PULP_CLI_BASE_URL or PULP_URL is required}"
: "${PULP_CLI_USERNAME:?PULP_CLI_USERNAME or PULP_USERNAME is required}"
: "${PULP_CLI_PASSWORD:?PULP_CLI_PASSWORD or PULP_PASSWORD is required}"

export PULP_CLI_BASE_URL PULP_CLI_USERNAME PULP_CLI_PASSWORD

RPM_REPOSITORY="${RPM_REPOSITORY:-ci-rpm}"
DEB_REPOSITORY="${DEB_REPOSITORY:-ci-deb}"

log() {
  echo "[PULP] $*"
}

ensure_rpm_repository() {
  if pulp rpm repository show --name "${RPM_REPOSITORY}" >/dev/null 2>&1; then
    log "RPM repository exists: ${RPM_REPOSITORY}"
  else
    log "Creating RPM repository: ${RPM_REPOSITORY}"
    pulp rpm repository create --name "${RPM_REPOSITORY}"
  fi
}

ensure_deb_repository() {
  if pulp deb repository show --name "${DEB_REPOSITORY}" >/dev/null 2>&1; then
    log "DEB repository exists: ${DEB_REPOSITORY}"
  else
    log "Creating DEB repository: ${DEB_REPOSITORY}"
    pulp deb repository create --name "${DEB_REPOSITORY}"
  fi
}

ensure_rpm_distribution() {
  if pulp rpm distribution show --name "${RPM_REPOSITORY}" >/dev/null 2>&1; then
    log "RPM distribution exists: ${RPM_REPOSITORY}"
  else
    log "Creating RPM distribution: ${RPM_REPOSITORY}"
    pulp rpm distribution create --name "${RPM_REPOSITORY}" --repository "${RPM_REPOSITORY}" --base-path "${RPM_REPOSITORY}"
  fi
}

ensure_deb_distribution() {
  if pulp deb distribution show --name "${DEB_REPOSITORY}" >/dev/null 2>&1; then
    log "DEB distribution exists: ${DEB_REPOSITORY}"
  else
    log "Creating DEB distribution: ${DEB_REPOSITORY}"
    pulp deb distribution create --name "${DEB_REPOSITORY}" --repository "${DEB_REPOSITORY}" --base-path "${DEB_REPOSITORY}"
  fi
}

ensure_rpm_repository
ensure_deb_repository
ensure_rpm_distribution
ensure_deb_distribution
