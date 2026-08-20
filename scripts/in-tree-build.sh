#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"
STAGE="${1:?stage required: preflight|build|pack}"

require_dir "$SOURCE_DIR"
require_dir "$GENERATED_DEVICE_DIR"
require_file "$ROCK960_ANDROID_BASE_DTSI"
require_file "$ROCK960_ANDROID_DTS"

source_build_env

UBOOT_DEFCONFIG="$(get_build_var PRODUCT_UBOOT_CONFIG)"
KERNEL_ARCH="$(get_build_var PRODUCT_KERNEL_ARCH)"
KERNEL_CONFIG="$(get_build_var PRODUCT_KERNEL_CONFIG)"
KERNEL_DTS="$(get_build_var PRODUCT_KERNEL_DTS)"
PRODUCT_OUT="$(get_build_var PRODUCT_OUT)"
PRODUCT_DYNAMIC="$(get_build_var PRODUCT_USE_DYNAMIC_PARTITIONS)"
BOARD_AVB_ACTUAL="$(get_build_var BOARD_AVB_ENABLE)"
PLATFORM_PRODUCT="$(get_build_var TARGET_BOARD_PLATFORM_PRODUCT)"
CAMERA_ACTUAL="$(get_build_var PRODUCT_SUPPORTS_CAMERA 2>/dev/null || true)"
ETHERNET_ACTUAL="$(get_build_var BOARD_HS_ETHERNET 2>/dev/null || true)"
TARGET_DEVICE_DIR_ACTUAL="$(get_build_var TARGET_DEVICE_DIR 2>/dev/null || true)"
TARGET_BASE_PARAMETER_IMAGE="$(get_build_var TARGET_BASE_PARAMETER_IMAGE 2>/dev/null || true)"

[[ "$KERNEL_DTS" == "rk3399-rock960-ab-android" ]] || die "unexpected kernel DTS after lunch: $KERNEL_DTS"
[[ "$UBOOT_DEFCONFIG" == "rk3399" ]] || warn "unexpected U-Boot config: $UBOOT_DEFCONFIG"
[[ "$PRODUCT_DYNAMIC" == "true" ]] || die "expected Android 11 RK3399 ATV dynamic partitions"
[[ "$PLATFORM_PRODUCT" == "atv" ]] || die "expected TARGET_BOARD_PLATFORM_PRODUCT=atv, got: $PLATFORM_PRODUCT"
[[ "$TARGET_DEVICE_DIR_ACTUAL" == "$GENERATED_DEVICE_DIR_REL" ]] || die "unexpected TARGET_DEVICE_DIR: $TARGET_DEVICE_DIR_ACTUAL"

for fragment in rockchip_defconfig android-10.config android-11.config; do
  [[ " $KERNEL_CONFIG " == *" $fragment "* ]] || die "kernel config is missing required fragment: $fragment (actual: $KERNEL_CONFIG)"
done

EXPECTED_AVB=false
[[ "$ENABLE_AVB" == 1 ]] && EXPECTED_AVB=true
[[ "$BOARD_AVB_ACTUAL" == "$EXPECTED_AVB" ]] || die "AVB config mismatch: controller expects $EXPECTED_AVB, Android build resolved $BOARD_AVB_ACTUAL"

EXPECTED_CAMERA=false
[[ "$ENABLE_CAMERA" == 1 ]] && EXPECTED_CAMERA=true
[[ -z "$CAMERA_ACTUAL" || "$CAMERA_ACTUAL" == "$EXPECTED_CAMERA" ]] || die "camera product policy mismatch: controller expects $EXPECTED_CAMERA, Android build resolved $CAMERA_ACTUAL"

EXPECTED_ETHERNET=false
[[ "$ENABLE_ETHERNET" == 1 ]] && EXPECTED_ETHERNET=true
[[ -z "$ETHERNET_ACTUAL" || "$ETHERNET_ACTUAL" == "$EXPECTED_ETHERNET" ]] || die "Ethernet policy mismatch: controller expects $EXPECTED_ETHERNET, Android build resolved $ETHERNET_ACTUAL"

log "resolved build contract: DTS=$KERNEL_DTS kernel=[$KERNEL_CONFIG] ATV=$PLATFORM_PRODUCT AVB=$BOARD_AVB_ACTUAL camera=${CAMERA_ACTUAL:-unknown} ethernet=${ETHERNET_ACTUAL:-unknown}"

verify_wifi_payload() {
  local source_fw_dir vendor_fw_dir src dst src_hash dst_hash
  source_fw_dir="$SOURCE_DIR/vendor/rockchip/common/wifi/firmware"
  vendor_fw_dir="$PRODUCT_OUT/vendor/etc/firmware"

  while read -r src dst; do
    require_file "$source_fw_dir/$src"
    require_file "$vendor_fw_dir/$dst"
    if ! cmp -s "$source_fw_dir/$src" "$vendor_fw_dir/$dst"; then
      die "Wi-Fi payload mismatch: $src was not copied byte-for-byte as $dst"
    fi
    src_hash="$(sha256sum "$source_fw_dir/$src" | awk '{print $1}')"
    dst_hash="$(sha256sum "$vendor_fw_dir/$dst" | awk '{print $1}')"
    [[ "$src_hash" == "$dst_hash" ]] || die "Wi-Fi SHA-256 mismatch for $dst"
    log "Wi-Fi payload verified: $dst <= $src ($dst_hash)"
  done <<'EOF_WIFI'
fw_bcm4356a2_ag.bin fw_bcmdhd.bin
fw_bcm4356a2_ag_apsta.bin fw_bcmdhd_apsta.bin
fw_bcm4356a2_ag_p2p.bin fw_bcmdhd_p2p.bin
nvram_ap6356s.txt nvram.txt
EOF_WIFI
}

write_wifi_hashes() {
  local vendor_fw_dir="$PRODUCT_OUT/vendor/etc/firmware"
  mkdir -p "$ARTIFACT_DIR/latest"
  (
    cd "$vendor_fw_dir"
    sha256sum fw_bcmdhd.bin fw_bcmdhd_apsta.bin fw_bcmdhd_p2p.bin nvram.txt
  ) > "$ARTIFACT_DIR/latest/WIFI-SHA256SUMS.txt"
}

if [[ "$USE_CCACHE" == 1 ]]; then
  export USE_CCACHE=1
  export CCACHE_DIR
  ccache -M "${CCACHE_MAX_GB}G" >/dev/null || true
  log "ccache enabled at $CCACHE_DIR (${CCACHE_MAX_GB} GiB max)"
else
  unset USE_CCACHE || true
fi

build_uboot() {
  log "building RK3399 Android U-Boot ($UBOOT_DEFCONFIG) for compatibility validation/debug artifacts"
  (
    cd u-boot
    make clean >/dev/null 2>&1 || true
    make mrproper >/dev/null 2>&1 || true
    make distclean >/dev/null 2>&1 || true
    ./make.sh "$UBOOT_DEFCONFIG"
  )
  require_file "$SOURCE_DIR/u-boot/uboot.img"
}

build_kernel() {
  local -a cfgs
  read -r -a cfgs <<< "$KERNEL_CONFIG"
  log "building kernel config: ${cfgs[*]}"
  make -C kernel ARCH="$KERNEL_ARCH" "${cfgs[@]}"
  log "building kernel image/DTB: ${KERNEL_DTS}.img with -j${BUILD_JOBS}"
  make -C kernel ARCH="$KERNEL_ARCH" "${KERNEL_DTS}.img" -j"$BUILD_JOBS"
  require_file "$SOURCE_DIR/kernel/arch/arm64/boot/Image"
  require_file "$SOURCE_DIR/kernel/arch/arm64/boot/dts/rockchip/${KERNEL_DTS}.dtb"
  if [[ -x u-boot/scripts/pack_resource.sh && -f kernel/resource.img ]]; then
    u-boot/scripts/pack_resource.sh kernel/resource.img
  fi
}

parse_android() {
  log "running Soong/Kati graph generation only (m nothing)"
  m nothing -j"$BUILD_JOBS"
}

build_android() {
  local build_number
  build_number="${BUILD_NUMBER:-rock960-$(date -u +%Y%m%d%H%M)}"
  log "installclean before full Android build"
  make installclean
  log "full Android build: $PRODUCT_LUNCH, BUILD_NUMBER=$build_number, -j${BUILD_JOBS}"
  make -j"$BUILD_JOBS" BUILD_NUMBER="$build_number"
  require_file "$PRODUCT_OUT/boot.img"
  require_file "$PRODUCT_OUT/super.img"
  verify_wifi_payload
}

find_trust() {
  local f
  for f in u-boot/trust_nand.img u-boot/trust_with_ta.img u-boot/trust.img; do
    [[ -f "$f" ]] && { printf '%s\n' "$f"; return 0; }
  done
  die "U-Boot trust image not found"
}

copy_required() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || die "required image missing: $src"
  cp -a "$src" "$dst"
}

pack_update() {
  local rockdev image_dir trust baseparam dtbo vbmeta final_name debug_dir
  verify_wifi_payload
  rockdev="$SOURCE_DIR/RKTools/linux/Linux_Pack_Firmware/rockdev"
  image_dir="$rockdev/Image-${PRODUCT_NAME}"
  require_dir "$rockdev"
  require_file "$rockdev/afptool"
  require_file "$rockdev/rkImageMaker"
  require_file "$rockdev/gen-package-file.sh"
  rm -rf "$image_dir"
  mkdir -p "$image_dir"

  copy_required "$PRODUCT_OUT/boot.img" "$image_dir/boot.img"
  copy_required "$PRODUCT_OUT/recovery.img" "$image_dir/recovery.img"
  copy_required "$PRODUCT_OUT/super.img" "$image_dir/super.img"

  if [[ -f "$PRODUCT_OUT/dtbo.img" ]]; then dtbo="$PRODUCT_OUT/dtbo.img"; else dtbo="$PRODUCT_OUT/rebuild-dtbo.img"; fi
  copy_required "$dtbo" "$image_dir/dtbo.img"

  if [[ "$BOARD_AVB_ACTUAL" == "true" ]]; then
    vbmeta="$PRODUCT_OUT/vbmeta.img"
  else
    vbmeta="$SOURCE_DIR/device/rockchip/common/vbmeta.img"
  fi
  copy_required "$vbmeta" "$image_dir/vbmeta.img"

  copy_required "$SOURCE_DIR/rkst/Image/misc.img" "$image_dir/misc.img"
  copy_required "$GENERATED_DEVICE_DIR/parameter.txt" "$image_dir/parameter.txt"

  baseparam="$TARGET_BASE_PARAMETER_IMAGE"
  if [[ -n "$baseparam" && "$baseparam" = /* && -f "$baseparam" ]]; then
    copy_required "$baseparam" "$image_dir/baseparameter.img"
  else
    if [[ -z "$baseparam" || ! -f "$SOURCE_DIR/$baseparam" ]]; then
      baseparam="device/rockchip/common/baseparameter/v1.0/baseparameter.img"
    fi
    copy_required "$SOURCE_DIR/$baseparam" "$image_dir/baseparameter.img"
  fi

  # Keep resource.img as an inspection artifact when available. It is already
  # embedded in the Android boot image path used by this port and is not a
  # separate partition payload for the current header-v2 layout.
  [[ -f kernel/resource.img ]] && cp -a kernel/resource.img "$image_dir/resource.img"

  # Critical first-boot policy: do NOT place uboot.img or trust.img in image_dir.
  # pack-safe-update.sh generates the package-file from files actually present,
  # so the existing ROCK960 persistent boot chain is not overwritten.
  "$CONTROLLER_DIR/scripts/pack-safe-update.sh" "$image_dir" "$rockdev/update.img"
  require_file "$rockdev/update.img"

  mkdir -p "$ARTIFACT_DIR/latest"
  final_name="ROCK960-AndroidTV11-ASUS-2.0.8-$(date -u +%Y%m%d-%H%M)-update.img"
  cp -a "$rockdev/update.img" "$ARTIFACT_DIR/latest/$final_name"

  rm -rf "$ARTIFACT_DIR/latest/images" "$ARTIFACT_DIR/latest/bootloader-debug"
  cp -a "$image_dir" "$ARTIFACT_DIR/latest/images"

  # U-Boot/trust are still compiled and retained for UART/debug comparison,
  # but are deliberately outside the flash payload directory.
  debug_dir="$ARTIFACT_DIR/latest/bootloader-debug"
  mkdir -p "$debug_dir"
  copy_required "$SOURCE_DIR/u-boot/uboot.img" "$debug_dir/uboot.img"
  trust="$(find_trust)"
  copy_required "$SOURCE_DIR/$trust" "$debug_dir/trust.img"
  [[ -f u-boot/idbloader.img ]] && cp -a u-boot/idbloader.img "$debug_dir/idbloader.img"

  write_wifi_hashes
  (cd "$ARTIFACT_DIR/latest" && sha256sum "$final_name" > SHA256SUMS.txt)
  log "packed safe first-boot RKUpdate image: $ARTIFACT_DIR/latest/$final_name"
}

case "$STAGE" in
  preflight)
    build_uboot
    build_kernel
    parse_android
    ;;
  build)
    build_uboot
    build_kernel
    build_android
    ;;
  pack)
    pack_update
    ;;
  *) die "unknown build stage: $STAGE" ;;
esac
