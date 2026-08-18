#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"
mkdir -p "$ARTIFACT_DIR"
log "starting full build"
run_build_stage build 2>&1 | tee "$ARTIFACT_DIR/full-build.log"
