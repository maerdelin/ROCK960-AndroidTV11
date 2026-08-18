#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

ensure_workspace
require_cmd git
require_cmd curl
require_cmd python3
require_cmd awk
require_cmd df
require_cmd sha256sum

log "controller: $CONTROLLER_DIR"
log "workspace:  $WORKSPACE"
log "source:     $SOURCE_DIR"
log "artifacts:  $ARTIFACT_DIR"
log "lunch:      $PRODUCT_LUNCH"
log "build env:  $(choose_build_env)"

DISK_GB="$(available_disk_gb "$WORKSPACE")"
MEM_GB="$(memory_plus_swap_gb)"
log "free disk at workspace: ${DISK_GB} GiB"
log "RAM + swap: ${MEM_GB} GiB"

if (( DISK_GB < MIN_DISK_GB )); then
  die "need at least ${MIN_DISK_GB} GiB free at WORKSPACE; found ${DISK_GB} GiB"
fi
if (( MEM_GB < MIN_MEMORY_PLUS_SWAP_GB )); then
  die "need at least ${MIN_MEMORY_PLUS_SWAP_GB} GiB RAM+swap for the conservative build profile; found ${MEM_GB} GiB. Add swap first."
fi

FS_TYPE="$(df -T "$WORKSPACE" | awk 'NR==2 {print $2}')"
case "$FS_TYPE" in
  ext4|xfs|btrfs) log "filesystem: $FS_TYPE" ;;
  *) warn "workspace filesystem is $FS_TYPE. Android source trees are safest on a native Linux filesystem (ext4/xfs/btrfs); avoid NTFS/exFAT." ;;
esac

if [[ "$(choose_build_env)" == docker ]]; then
  docker info >/dev/null 2>&1 || die "docker is installed but the daemon is not usable by this user"
fi

log "doctor checks passed"
