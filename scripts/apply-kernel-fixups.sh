#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

PATCH="$CONTROLLER_DIR/patches/rock960-kernel-build-fixups.patch"
KERNEL_DIR="$SOURCE_DIR/kernel"

require_dir "$KERNEL_DIR"
require_file "$PATCH"
require_cmd git

if git -C "$KERNEL_DIR" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
  log "ROCK960 kernel build fixups already applied"
elif git -C "$KERNEL_DIR" apply --check "$PATCH" >/dev/null 2>&1; then
  log "applying verified ROCK960 kernel build fixups"
  git -C "$KERNEL_DIR" apply --whitespace=nowarn "$PATCH"
else
  die "kernel fixup patch matches neither a clean ASUS 2.0.8 tree nor an already-fixed tree"
fi

# Refuse to continue if the two verified source-level effects are not present.
grep -q 'ROCK960 does not use the Tinker Board AT24 EEPROM' \
  "$KERNEL_DIR/drivers/net/ethernet/stmicro/stmmac/eth_mac_tinker.c" \
  || die "Ethernet ROCK960 fixup marker is missing after patch application"

grep -q '#if defined(CONFIG_TINKER_MCU)' \
  "$KERNEL_DIR/drivers/gpu/drm/panel/panel-simple.c" \
  || die "panel-simple Tinker MCU guard is missing after patch application"

log "ROCK960 kernel fixups verified"
