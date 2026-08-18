#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

if [[ -d "$GENERATED_DEVICE_DIR" ]]; then
  log "removing generated product: $GENERATED_DEVICE_DIR"
  rm -rf "$GENERATED_DEVICE_DIR"
fi
for f in "$ROCK960_ANDROID_DTS" "$ROCK960_ANDROID_BASE_DTSI"; do
  if [[ -f "$f" ]]; then
    log "removing generated DTS artifact: $f"
    rm -f "$f"
  fi
done
