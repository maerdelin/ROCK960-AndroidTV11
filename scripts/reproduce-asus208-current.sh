#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/reproduce-asus208-current.sh \
    --firmware /path/Tinker_Board_2-Android11-v2.0.8-20220503.img \
    --out /path/ROCK960-Android11-v2.0.8-update.img

One-command reproduction of the 2026-08-20 minimal bring-up image:
1. apply/generate the pinned ROCK960 port;
2. source-audit the generated tree;
3. configure/build the ROCK960 kernel and repack the official ASUS boot image;
4. rebuild the RKUpdate image from official ASUS Android partitions + verified ROCK960 boot;
5. use the safe package policy (MiniLoader outer loader, no persistent uboot/trust payloads).
USAGE
}

FIRMWARE=""
OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --firmware) FIRMWARE="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$FIRMWARE" && -n "$OUT" ]] || { usage; exit 2; }
require_file "$FIRMWARE"
ensure_workspace

work="$(mktemp -d "${WORKSPACE%/}/reproduce-asus208-current.XXXXXX")"
trap 'rm -rf "$work"' EXIT
BOOT="$work/rock960-test-boot.img"

log "STEP 1/4: apply/generate pinned ROCK960 port"
"$CONTROLLER_DIR/scripts/apply-port.sh"

log "STEP 2/4: source/hardware contract audit"
"$CONTROLLER_DIR/scripts/audit-source.sh"

log "STEP 3/4: build and verify ASUS-ramdisk + ROCK960 kernel/DTB/resource boot.img"
"$CONTROLLER_DIR/scripts/repack-asus208-boot.sh" \
  --firmware "$FIRMWARE" \
  --out "$BOOT"

log "STEP 4/4: pack and verify exact-current safe RKUpdate image"
"$CONTROLLER_DIR/scripts/repack-asus208-current.sh" \
  --firmware "$FIRMWARE" \
  --boot "$BOOT" \
  --out "$OUT"

require_file "$OUT"
require_file "$OUT.sha256"
log "exact 2026-08-20 bring-up workflow reproduced successfully: $OUT"
