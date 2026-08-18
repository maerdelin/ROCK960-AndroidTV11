#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

log "ROCK960 Android TV 11 / ASUS BSP one-shot build"
"$CONTROLLER_DIR/scripts/doctor.sh"
if [[ "${SKIP_NETWORK_PREFLIGHT:-0}" != 1 ]]; then
  "$CONTROLLER_DIR/scripts/network-preflight.sh"
fi
"$CONTROLLER_DIR/scripts/sync.sh"
"$CONTROLLER_DIR/scripts/apply-port.sh"
"$CONTROLLER_DIR/scripts/audit-source.sh"
"$CONTROLLER_DIR/scripts/preflight-build.sh"
"$CONTROLLER_DIR/scripts/build.sh"
"$CONTROLLER_DIR/scripts/pack.sh"
"$CONTROLLER_DIR/scripts/verify-artifacts.sh"
log "DONE. Firmware is under: $ARTIFACT_DIR/latest"
