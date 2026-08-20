#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/repack-asus208-current.sh \
    --firmware /path/Tinker_Board_2-Android11-v2.0.8-20220503.img \
    --boot /path/rock960-test-boot.img \
    --out /path/ROCK960-Android11-v2.0.8-update.img

This reproduces the 2026-08-20 minimal bring-up package:
- ASUS 2.0.8 Android partitions from the official raw GPT image;
- the already verified ROCK960 boot.img;
- RKUpdate MiniLoaderAll.bin from the pinned rkbin tree;
- no persistent uboot.img/trust.img payloads.
USAGE
}

FIRMWARE=""
BOOT=""
OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --firmware) FIRMWARE="${2:-}"; shift 2 ;;
    --boot) BOOT="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$FIRMWARE" && -n "$BOOT" && -n "$OUT" ]] || { usage; exit 2; }
require_file "$FIRMWARE"
require_file "$BOOT"
require_dir "$SOURCE_DIR/RKTools"
require_dir "$SOURCE_DIR/rkbin"
for cmd in sfdisk dd python3 stat awk cut; do require_cmd "$cmd"; done
ensure_workspace

work="$(mktemp -d "${WORKSPACE%/}/repack-asus208.XXXXXX")"
trap 'rm -rf "$work"' EXIT
IMAGE="$work/Image"
PARTS="$work/parts.tsv"
mkdir -p "$IMAGE"

log "deriving parameter.txt directly from the official ASUS 2.0.8 GPT"
python3 - "$FIRMWARE" "$IMAGE/parameter.txt" "$PARTS" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

img = sys.argv[1]
param_out = Path(sys.argv[2])
parts_out = Path(sys.argv[3])
text = subprocess.check_output(["sfdisk", "-d", img], text=True)
parts = []
for line in text.splitlines():
    m = re.search(r':\s*start=\s*(\d+),\s*size=\s*(\d+).*?name="([^"]+)"', line)
    if m:
        parts.append((m.group(3), int(m.group(1)), int(m.group(2))))
if not parts:
    raise SystemExit("ERROR: no GPT partitions parsed from firmware")

required = {"uboot", "trust", "misc", "boot", "recovery", "dtbo", "vbmeta", "baseparameter", "super", "userdata"}
missing = sorted(required - {name for name, _, _ in parts})
if missing:
    raise SystemExit("ERROR: official image is missing expected partitions: " + ", ".join(missing))

entries = []
for name, start, size in parts:
    if name == "userdata":
        entries.append(f"-@0x{start:08x}(userdata:grow)")
    else:
        entries.append(f"0x{size:08x}@0x{start:08x}({name})")

parameter = (
    "FIRMWARE_VER: 11.0.0\n"
    "MACHINE_MODEL: rk3399\n"
    "MACHINE_ID: 007\n"
    "MANUFACTURER: rockchip\n"
    "MAGIC: 0x5041524B\n"
    "ATAG: 0x00200800\n"
    "MACHINE: Tinker_Board_2\n"
    "CHECK_MASK: 0x80\n"
    "PWR_HLD: 0,0,A,0,1\n"
    "TYPE: GPT\n"
    "CMDLINE:mtdparts=rk29xxnand:" + ",".join(entries) + "\n"
)
param_out.write_text(parameter)
with parts_out.open("w") as f:
    for name, start, size in parts:
        f.write(f"{name}\t{start}\t{size}\n")
PY

assert_geometry() {
  local name="$1" expect_start="$2" expect_size="$3" row start size
  row="$(awk -F '\t' -v n="$name" '$1 == n {print; exit}' "$PARTS")"
  [[ -n "$row" ]] || die "missing expected partition: $name"
  start="$(printf '%s\n' "$row" | cut -f2)"
  size="$(printf '%s\n' "$row" | cut -f3)"
  [[ "$start" == "$expect_start" && "$size" == "$expect_size" ]] \
    || die "unexpected ASUS 2.0.8 $name geometry: start=$start size=$size; expected start=$expect_start size=$expect_size"
}

# These are the exact boot-critical locations used by the pinned RK3399 layout.
# uboot/trust match the ROCK960 A/B RK3399 slots; boot is the 40 MiB ASUS 2.0.8 slot.
assert_geometry uboot 16384 8192
assert_geometry trust 24576 8192
assert_geometry boot 59392 81920
assert_geometry super 2011136 6373376

extract_part() {
  local name="$1" row start sectors
  row="$(awk -F '\t' -v n="$name" '$1 == n {print; exit}' "$PARTS")"
  [[ -n "$row" ]] || die "partition not found in official image: $name"
  start="$(printf '%s\n' "$row" | cut -f2)"
  sectors="$(printf '%s\n' "$row" | cut -f3)"
  log "extracting $name (start=$start sectors=$sectors)"
  dd if="$FIRMWARE" of="$IMAGE/$name.img" bs=512 skip="$start" count="$sectors" status=progress
  require_file "$IMAGE/$name.img"
}

for part in misc dtbo vbmeta recovery baseparameter super; do
  extract_part "$part"
done

boot_row="$(awk -F '\t' '$1 == "boot" {print; exit}' "$PARTS")"
boot_sectors="$(printf '%s\n' "$boot_row" | cut -f3)"
boot_capacity=$((boot_sectors * 512))
boot_size="$(stat -c '%s' "$BOOT")"
(( boot_size <= boot_capacity )) \
  || die "verified ROCK960 boot.img is larger than the original boot partition"
cp -a "$BOOT" "$IMAGE/boot.img"
cmp "$BOOT" "$IMAGE/boot.img" >/dev/null || die "boot.img copy verification failed"

log "packing the same safe RKUpdate layout used by the 2026-08-20 bring-up"
"$CONTROLLER_DIR/scripts/pack-safe-update.sh" "$IMAGE" "$OUT"

log "minimal current-port package created: $OUT"
