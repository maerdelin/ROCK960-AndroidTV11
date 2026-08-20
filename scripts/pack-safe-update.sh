#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

IMAGE_DIR="${1:?usage: pack-safe-update.sh <image-dir> <output-update.img>}"
OUT="${2:?usage: pack-safe-update.sh <image-dir> <output-update.img>}"

require_dir "$IMAGE_DIR"
require_dir "$SOURCE_DIR"

ROCKDEV="$SOURCE_DIR/RKTools/linux/Linux_Pack_Firmware/rockdev"
RKBIN="$SOURCE_DIR/rkbin"
AFP="$ROCKDEV/afptool"
RKIM="$ROCKDEV/rkImageMaker"
GEN="$ROCKDEV/gen-package-file.sh"
BOOT_MERGER="$RKBIN/tools/boot_merger"
LOADER_INI="$RKBIN/RKBOOT/RK3399MINIALL.ini"

for f in "$AFP" "$RKIM" "$GEN" "$BOOT_MERGER" "$LOADER_INI"; do
  require_file "$f"
done

for f in boot.img misc.img dtbo.img vbmeta.img recovery.img baseparameter.img super.img parameter.txt; do
  require_file "$IMAGE_DIR/$f"
done

# First-boot safety policy: keep the board's persistent boot chain intact.
# The outer MiniLoaderAll.bin is still required by Rockchip RKUpdate/RKDevTool,
# but uboot.img and trust.img must not be payload entries in this package.
for forbidden in uboot.img trust.img; do
  [[ ! -e "$IMAGE_DIR/$forbidden" ]] \
    || die "refusing to package persistent $forbidden; keep it only as a debug artifact"
done

chmod +x "$AFP" "$RKIM" "$BOOT_MERGER"

loader_name="$(awk -F= '/^PATH=/{gsub(/\r/, "", $2); print $2; exit}' "$LOADER_INI")"
[[ -n "$loader_name" ]] || die "cannot determine loader output from $LOADER_INI"

log "building pinned RK3399 RKUpdate loader from rkbin: $loader_name"
(
  cd "$RKBIN"
  "$BOOT_MERGER" RKBOOT/RK3399MINIALL.ini >/dev/null
)
LOADER="$RKBIN/$loader_name"
require_file "$LOADER"
cp -a "$LOADER" "$IMAGE_DIR/MiniLoaderAll.bin"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
ln -s "$IMAGE_DIR" "$work/Image"

(
  cd "$work"
  bash "$GEN" Image > package-file-tmp
)

PACKAGE_FILE="$work/package-file-tmp"
require_file "$PACKAGE_FILE"

for name in boot misc dtbo vbmeta recovery baseparameter super; do
  grep -Eq "^${name}[[:space:]]" "$PACKAGE_FILE" \
    || die "generated package-file is missing required partition payload: $name"
done

if grep -Eq '^(uboot|trust)[[:space:]]' "$PACKAGE_FILE"; then
  die "generated package-file unexpectedly includes persistent uboot/trust"
fi

cp -a "$PACKAGE_FILE" "$IMAGE_DIR/package-file.generated"

log "packing inner Rockchip firmware payload"
(
  cd "$work"
  "$AFP" -pack ./ update-inner.img package-file-tmp
)
INNER="$work/update-inner.img"
require_file "$INNER"

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
log "wrapping RKUpdate image with rkImageMaker"
"$RKIM" -RK330C "$IMAGE_DIR/MiniLoaderAll.bin" "$INNER" "$OUT" -os_type:androidos
require_file "$OUT"

log "verifying packed boot.img payload byte-for-byte"
VERIFY="$work/verify"
mkdir -p "$VERIFY"
"$AFP" -unpack "$INNER" "$VERIFY" >/dev/null
PACKED_BOOT="$(find "$VERIFY" -type f -name boot.img -print -quit)"
[[ -n "$PACKED_BOOT" ]] || die "boot.img not found after afptool verification unpack"
cmp "$IMAGE_DIR/boot.img" "$PACKED_BOOT" >/dev/null \
  || die "packed boot.img does not match input boot.img"

sha256sum "$OUT" > "$OUT.sha256"
log "safe RKUpdate package verified: $OUT"
