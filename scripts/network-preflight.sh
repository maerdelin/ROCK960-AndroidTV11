#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

require_cmd git
require_cmd curl
require_cmd grep

check_ref() {
  local url="$1" ref="$2" label="$3"
  log "checking $label"
  if ! git ls-remote --exit-code "$url" "$ref" >/dev/null 2>&1; then
    die "cannot resolve $ref at $url ($label). Check DNS/proxy/firewall before repo sync."
  fi
}

check_ref "$ASUS_MANIFEST_URL" "refs/heads/$ASUS_MANIFEST_BRANCH" "ASUS manifest branch"
for spec in \
  "rockchip-android-device-rockchip-rk3399:RK3399 device" \
  "rockchip-android-device-rockchip-rksdk:Rockchip common device" \
  "rockchip-android-device-google-atv:AOSP ATV mirror" \
  "rockchip-android-kernel:kernel" \
  "rockchip-android-u-boot:U-Boot" \
  "rockchip-android-RKTools:RKTools" \
  "rockchip-android-rkbin:rkbin" \
  "rockchip-android-rkst:rkst" \
  "rockchip-android-vendor-rockchip-common:Rockchip vendor common" \
  "rockchip-android-vendor-rockchip-hardware:Rockchip vendor hardware"; do
  repo="${spec%%:*}"
  label="${spec#*:}"
  check_ref "https://github.com/TinkerBoard-Android/${repo}.git" "refs/tags/$ASUS_RELEASE_TAG" "$label release tag"
done

check_ref "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86" "refs/tags/$AOSP_RELEASE_TAG" "AOSP Android 11 prebuilts tag"

manifest_url="https://raw.githubusercontent.com/TinkerBoard-Android/rockchip-android-manifest/${ASUS_MANIFEST_BRANCH}/${ASUS_MANIFEST_FILE}"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
log "checking exact ASUS release manifest contents"
curl -fL --retry 3 --connect-timeout 15 "$manifest_url" -o "$tmp"
grep -Fq "revision=\"refs/tags/$ASUS_RELEASE_TAG\"" "$tmp" || die "manifest no longer defaults to $ASUS_RELEASE_TAG"
grep -Fq "<include name=\"$AOSP_RELEASE_TAG.xml\"" "$tmp" || die "manifest no longer includes $AOSP_RELEASE_TAG.xml"
for path in device/google/atv device/rockchip/common device/rockchip/rk3399 kernel u-boot RKTools rkbin rkst vendor/rockchip/common vendor/rockchip/hardware; do
  grep -Fq "path=\"$path\"" "$tmp" || die "manifest no longer contains required path: $path"
done

# The RK3399 ATV/ROCK960 port depends on these exact public files. HEAD requests are
# cheap and catch accidental source moves before a multi-hundred-GB repo sync.
for url in \
  "https://raw.githubusercontent.com/TinkerBoard-Android/rockchip-android-kernel/${ASUS_RELEASE_TAG}/arch/arm64/boot/dts/rockchip/rk3399-rock960-ab.dts" \
  "https://raw.githubusercontent.com/TinkerBoard-Android/rockchip-android-kernel/${ASUS_RELEASE_TAG}/arch/arm64/boot/dts/rockchip/rk3399-linux.dtsi" \
  "https://raw.githubusercontent.com/TinkerBoard-Android/rockchip-android-device-rockchip-rk3399/${ASUS_RELEASE_TAG}/rk3399_atv/parameter.txt" \
  "https://raw.githubusercontent.com/TinkerBoard-Android/rockchip-android-device-google-atv/${ASUS_RELEASE_TAG}/products/atv_base.mk"; do
  curl -fsSL --retry 2 --connect-timeout 10 "$url" -o /dev/null || die "required upstream file is unreachable: $url"
done

if ! curl -fsSI --retry 2 --connect-timeout 10 https://storage.googleapis.com/git-repo-downloads/repo >/dev/null 2>&1; then
  warn "Google repo launcher endpoint is unreachable; get-repo.sh will try the official Gerrit GitHub mirror fallback."
fi
log "network/source reference preflight passed"
