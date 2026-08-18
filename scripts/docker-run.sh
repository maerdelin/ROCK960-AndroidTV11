#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"
STAGE="${1:?stage required}"
require_cmd docker
require_dir "$SOURCE_DIR"
mkdir -p "$ARTIFACT_DIR" "$CCACHE_DIR"

if ! docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
  log "building reproducible Ubuntu 18.04 Android 11 build container"
  docker build \
    --build-arg USER_ID="$(id -u)" \
    --build-arg GROUP_ID="$(id -g)" \
    -t "$DOCKER_IMAGE" \
    -f "$CONTROLLER_DIR/docker/Dockerfile.android11" "$CONTROLLER_DIR/docker"
fi

exec docker run --rm --privileged --network host \
  -e ROCK960_IN_CONTAINER=1 \
  -e BUILD_JOBS="$BUILD_JOBS" \
  -e USE_CCACHE="$USE_CCACHE" \
  -e CCACHE_MAX_GB="$CCACHE_MAX_GB" \
  -e ENABLE_AVB="$ENABLE_AVB" \
  -v "$SOURCE_DIR:/source" \
  -v "$CONTROLLER_DIR:/controller:ro" \
  -v "$ARTIFACT_DIR:/artifacts" \
  -v "$CCACHE_DIR:/ccache" \
  -w /source \
  "$DOCKER_IMAGE" /bin/bash /controller/scripts/in-tree-build.sh "$STAGE"
