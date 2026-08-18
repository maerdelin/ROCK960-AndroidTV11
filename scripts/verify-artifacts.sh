#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"
LATEST="$ARTIFACT_DIR/latest"
require_dir "$LATEST"
IMG="$(find "$LATEST" -maxdepth 1 -type f -name '*-update.img' | sort | tail -n1 || true)"
[[ -n "$IMG" ]] || die "no update.img artifact found"
[[ -s "$IMG" ]] || die "update.img is empty"
IMG_SIZE="$(stat -c %s "$IMG")"
(( IMG_SIZE > 100 * 1024 * 1024 )) || die "update.img is suspiciously small (${IMG_SIZE} bytes)"
require_file "$LATEST/SHA256SUMS.txt"
require_file "$LATEST/WIFI-SHA256SUMS.txt"
(cd "$LATEST" && sha256sum -c SHA256SUMS.txt)
[[ "$(wc -l < "$LATEST/WIFI-SHA256SUMS.txt")" -eq 4 ]] || die "WIFI-SHA256SUMS.txt must contain exactly four AP6356S payload hashes"
for f in fw_bcmdhd.bin fw_bcmdhd_apsta.bin fw_bcmdhd_p2p.bin nvram.txt; do
  grep -Eq "^[0-9a-f]{64}[[:space:]]+$f$" "$LATEST/WIFI-SHA256SUMS.txt" || die "missing Wi-Fi hash entry: $f"
done
for f in boot.img recovery.img super.img dtbo.img vbmeta.img uboot.img trust.img MiniLoaderAll.bin parameter.txt baseparameter.img; do
  [[ -s "$LATEST/images/$f" ]] || die "missing packaged component: $f"
done
grep -Eq "MACHINE:[[:space:]]*3399|CMDLINE:.*super" "$LATEST/images/parameter.txt" || die "packaged parameter.txt does not look like the RK3399 ATV partition map"
grep -q "0x00614000@0x00159400(super)" "$LATEST/images/parameter.txt" || die "packaged parameter.txt lost the audited super partition layout"
log "artifact verification passed: $IMG"
