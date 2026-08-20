#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/repack-asus208-boot.sh \
    --firmware /path/Tinker_Board_2-Android11-v2.0.8-20220503.img \
    --out /path/rock960-test-boot.img

Run after `make port` and kernel configuration/build preparation. The script extracts
ASUS 2.0.8 boot.img, repacks it with the generated ROCK960 Android kernel/DTB/resource,
and verifies that the ASUS ramdisk/header/cmdline are preserved while the kernel changes.
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
require_dir "$SOURCE_DIR/kernel"
require_file "$ROCK960_ANDROID_DTS"
require_cmd sfdisk
require_cmd dd
require_cmd cmp
ensure_workspace

source_build_env
KERNEL_ARCH="$(get_build_var PRODUCT_KERNEL_ARCH)"
KERNEL_DTS="$(get_build_var PRODUCT_KERNEL_DTS)"
KERNEL_CONFIG="$(get_build_var PRODUCT_KERNEL_CONFIG)"
[[ "$KERNEL_DTS" == "rk3399-rock960-ab-android" ]] \
  || die "unexpected kernel DTS after lunch: $KERNEL_DTS"

work="$(mktemp -d "${WORKSPACE%/}/repack-asus208-boot.XXXXXX")"
trap 'rm -rf "$work"' EXIT
ORIG_BOOT="$work/asus-boot.img"
ORIG_UNPACK="$work/orig"
NEW_UNPACK="$work/new"

boot_line="$(sfdisk -d "$FIRMWARE" | grep -m1 'name="boot"' || true)"
[[ -n "$boot_line" ]] || die "official ASUS image has no GPT partition named boot"
start="$(printf '%s\n' "$boot_line" | sed -n 's/.*start= *\([0-9]*\).*/\1/p')"
sectors="$(printf '%s\n' "$boot_line" | sed -n 's/.*size= *\([0-9]*\).*/\1/p')"
[[ -n "$start" && -n "$sectors" ]] || die "failed to parse boot partition geometry"

dd if="$FIRMWARE" of="$ORIG_BOOT" bs=512 skip="$start" count="$sectors" status=progress
require_file "$ORIG_BOOT"

log "configuring pinned ROCK960 Android kernel: $KERNEL_CONFIG"
read -r -a cfgs <<< "$KERNEL_CONFIG"
make -C "$SOURCE_DIR/kernel" ARCH="$KERNEL_ARCH" HOSTCFLAGS="$KERNEL_HOSTCFLAGS" "${cfgs[@]}"

log "repacking ASUS boot.img with ROCK960 kernel target: ${KERNEL_DTS}.img"
(
  cd "$SOURCE_DIR"
  BOOT_IMG="$ORIG_BOOT" make -C kernel ARCH="$KERNEL_ARCH" HOSTCFLAGS="$KERNEL_HOSTCFLAGS" "${KERNEL_DTS}.img" -j"$BUILD_JOBS"
)
require_file "$SOURCE_DIR/kernel/boot.img"
require_file "$SOURCE_DIR/kernel/arch/arm64/boot/Image"
COMPILED_DTB="$SOURCE_DIR/kernel/arch/arm64/boot/dts/rockchip/${KERNEL_DTS}.dtb"
require_file "$COMPILED_DTB"
require_file "$SOURCE_DIR/kernel/resource.img"

mkdir -p "$(dirname "$OUT")"
cp -a "$SOURCE_DIR/kernel/boot.img" "$OUT"

UNPACK="$SOURCE_DIR/kernel/scripts/unpack_bootimg"
require_file "$UNPACK"
mkdir -p "$ORIG_UNPACK" "$NEW_UNPACK"
"$UNPACK" --boot_img "$ORIG_BOOT" --out "$ORIG_UNPACK" > "$work/orig.log"
"$UNPACK" --boot_img "$OUT" --out "$NEW_UNPACK" > "$work/new.log"

cmp "$ORIG_UNPACK/ramdisk" "$NEW_UNPACK/ramdisk" >/dev/null \
  || die "repacked boot.img changed the ASUS ramdisk"
cmp "$NEW_UNPACK/kernel" "$SOURCE_DIR/kernel/arch/arm64/boot/Image" >/dev/null \
  || die "repacked boot.img does not contain the built ROCK960 Image"
if cmp -s "$ORIG_UNPACK/kernel" "$NEW_UNPACK/kernel"; then
  die "repacked boot.img still contains the original ASUS kernel"
fi

cmp "$NEW_UNPACK/dtb" "$COMPILED_DTB" >/dev/null \
  || die "repacked boot.img does not contain the compiled ROCK960 DTB"
if cmp -s "$ORIG_UNPACK/dtb" "$NEW_UNPACK/dtb"; then
  die "repacked boot.img still contains the original ASUS DTB"
fi

cmp "$NEW_UNPACK/second" "$SOURCE_DIR/kernel/resource.img" >/dev/null \
  || die "repacked boot.img second stage does not match the built ROCK960 resource.img"

header_re='^(boot image header version|os version|os patch level|command line args|additional command line args):'
grep -E "$header_re" "$work/orig.log" > "$work/orig.header"
grep -E "$header_re" "$work/new.log" > "$work/new.header"
cmp "$work/orig.header" "$work/new.header" >/dev/null \
  || die "repacked boot.img changed ASUS header/cmdline metadata"

log "boot repack verified: ASUS ramdisk/header preserved; ROCK960 kernel/DTB/resource installed: $OUT"
