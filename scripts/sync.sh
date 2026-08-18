#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

ensure_workspace
REPO_BIN="$($CONTROLLER_DIR/scripts/get-repo.sh)"
mkdir -p "$SOURCE_DIR"
cd "$SOURCE_DIR"

log "initializing ASUS Tinker Board 2 Android 11 2.0.8 manifest"
"$REPO_BIN" init \
  -u "$ASUS_MANIFEST_URL" \
  -b "$ASUS_MANIFEST_BRANCH" \
  -m "$ASUS_MANIFEST_FILE" \
  --repo-url="$REPO_IMPLEMENTATION_URL"

# Fail before the expensive sync if the selected manifest changed materially.
MANIFEST_CHECK="$SOURCE_DIR/.repo/manifests/$ASUS_MANIFEST_FILE"
require_file "$MANIFEST_CHECK"
grep -Fq "revision=\"refs/tags/$ASUS_RELEASE_TAG\"" "$MANIFEST_CHECK" || die "selected manifest no longer pins $ASUS_RELEASE_TAG"
grep -Fq "<include name=\"$AOSP_RELEASE_TAG.xml\"" "$MANIFEST_CHECK" || die "selected manifest no longer includes $AOSP_RELEASE_TAG.xml"
for path in device/google/atv device/rockchip/common device/rockchip/rk3399 kernel u-boot RKTools rkbin rkst vendor/rockchip/common vendor/rockchip/hardware; do
  grep -Fq "path=\"$path\"" "$MANIFEST_CHECK" || die "selected manifest lacks required path: $path"
done

log "syncing source with ${SYNC_JOBS} jobs"
SYNC_ARGS=(-c --fail-fast --force-sync --no-clone-bundle --prune)
if ! "$REPO_BIN" sync "${SYNC_ARGS[@]}" -j"$SYNC_JOBS"; then
  warn "parallel repo sync failed; retrying once with -j1 to expose the failing project clearly"
  "$REPO_BIN" sync "${SYNC_ARGS[@]}" -j1
fi

mkdir -p "$ARTIFACT_DIR/manifests"
"$REPO_BIN" manifest -r -o "$ARTIFACT_DIR/manifests/resolved.xml"
log "source sync complete"
