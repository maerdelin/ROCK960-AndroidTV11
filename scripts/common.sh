#!/usr/bin/env bash
set -euo pipefail

CONTROLLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$CONTROLLER_DIR/config/default.env"
if [[ -f "$CONTROLLER_DIR/config/local.env" ]]; then
  # shellcheck disable=SC1091
  source "$CONTROLLER_DIR/config/local.env"
fi

if [[ "${ROCK960_IN_CONTAINER:-0}" == "1" ]]; then
  WORKSPACE="/work"
  SOURCE_DIR="/source"
  ARTIFACT_DIR="/artifacts"
  CCACHE_DIR="/ccache"
fi

PRODUCT_LUNCH="${PRODUCT_NAME}-${BUILD_VARIANT}"
GENERATED_DEVICE_DIR_REL="device/rockchip/rk3399/${PRODUCT_NAME}"
GENERATED_DEVICE_DIR="${SOURCE_DIR}/${GENERATED_DEVICE_DIR_REL}"
UPSTREAM_DEVICE_DIR="${SOURCE_DIR}/device/rockchip/rk3399/rk3399_atv"
KERNEL_DTS_DIR="${SOURCE_DIR}/kernel/arch/arm64/boot/dts/rockchip"
ROCK960_BASE_DTS="${KERNEL_DTS_DIR}/rk3399-rock960-ab.dts"
ROCK960_LINUX_DTSI="${KERNEL_DTS_DIR}/rk3399-linux.dtsi"
ROCK960_ANDROID_BASE_DTSI="${KERNEL_DTS_DIR}/rk3399-rock960-android-base.dtsi"
ROCK960_ANDROID_DTS="${KERNEL_DTS_DIR}/rk3399-rock960-ab-android.dts"

log()  { printf '[rock960] %s\n' "$*"; }
warn() { printf '[rock960][WARN] %s\n' "$*" >&2; }
die()  { printf '[rock960][ERROR] %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_file() {
  [[ -f "$1" ]] || die "required file not found: $1"
}

require_dir() {
  [[ -d "$1" ]] || die "required directory not found: $1"
}

ensure_workspace() {
  mkdir -p "$WORKSPACE" "$ARTIFACT_DIR" "$(dirname "$SOURCE_DIR")"
}

source_build_env() {
  cd "$SOURCE_DIR"
  # shellcheck disable=SC1091
  source build/envsetup.sh >/dev/null
  lunch "$PRODUCT_LUNCH" >/dev/null
}

memory_plus_swap_gb() {
  awk '/MemTotal:/ {m=$2} /SwapTotal:/ {s=$2} END {printf "%d\n", (m+s)/1024/1024}' /proc/meminfo
}

available_disk_gb() {
  local path="$1"
  mkdir -p "$path"
  df -Pk "$path" | awk 'NR==2 {printf "%d\n", $4/1024/1024}'
}

choose_build_env() {
  case "$BUILD_ENV" in
    host) echo host ;;
    docker) command -v docker >/dev/null 2>&1 || die "BUILD_ENV=docker but docker is unavailable"; echo docker ;;
    auto)
      if command -v docker >/dev/null 2>&1; then echo docker; else echo host; fi
      ;;
    *) die "BUILD_ENV must be auto, docker, or host" ;;
  esac
}

run_build_stage() {
  local stage="$1"
  local mode
  mode="$(choose_build_env)"
  if [[ "$mode" == docker ]]; then
    "$CONTROLLER_DIR/scripts/docker-run.sh" "$stage"
  else
    "$CONTROLLER_DIR/scripts/in-tree-build.sh" "$stage"
  fi
}
