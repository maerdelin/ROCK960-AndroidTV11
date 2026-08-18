#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"
mkdir -p "$ARTIFACT_DIR"
run_build_stage pack 2>&1 | tee "$ARTIFACT_DIR/pack.log"
