#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

require_dir "$SOURCE_DIR"
require_dir "$UPSTREAM_DEVICE_DIR"
require_file "$ROCK960_BASE_DTS"

log "generating $PRODUCT_NAME from ASUS/Rockchip rk3399_atv"
python3 "$CONTROLLER_DIR/tools/port_product.py" \
  --source "$SOURCE_DIR" \
  --product "$PRODUCT_NAME" \
  --model "$PRODUCT_MODEL" \
  --avb "$ENABLE_AVB" \
  --widevine "$ENABLE_WIDEVINE_L3" \
  --playready "$ENABLE_PLAYREADY" \
  --gms "$ENABLE_GMS" \
  --gtvs "$ENABLE_GTVS" \
  --camera "$ENABLE_CAMERA" \
  --ethernet "$ENABLE_ETHERNET"

log "generating Android-specific ROCK960 kernel DTS"
python3 "$CONTROLLER_DIR/tools/make_rock960_android_dts.py" \
  --base "$ROCK960_BASE_DTS" \
  --output "$ROCK960_ANDROID_DTS"

log "port generation complete"
