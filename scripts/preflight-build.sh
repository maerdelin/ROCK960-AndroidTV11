#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"
mkdir -p "$ARTIFACT_DIR"
log "preflight will compile U-Boot + kernel/DTS and generate the Android build graph"
run_build_stage preflight 2>&1 | tee "$ARTIFACT_DIR/preflight-build.log"
