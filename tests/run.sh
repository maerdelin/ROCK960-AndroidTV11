#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cleanup_pycache() {
  find "$ROOT" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
}
trap cleanup_pycache EXIT

python3 -m unittest discover -s "$ROOT/tests" -p 'test_*.py' -v
find "$ROOT/scripts" -maxdepth 1 -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
python3 -m py_compile "$ROOT/tools/port_product.py" "$ROOT/tools/make_rock960_android_dts.py"

# 2026-08-20 bring-up closure must remain wired into normal builds.
grep -q 'apply-kernel-fixups.sh' "$ROOT/scripts/apply-port.sh"
grep -q 'rock960-kernel-build-fixups.patch' "$ROOT/scripts/apply-kernel-fixups.sh"
grep -q 'pack-safe-update.sh' "$ROOT/scripts/in-tree-build.sh"
grep -q 'generated package-file unexpectedly includes persistent uboot/trust' "$ROOT/scripts/pack-safe-update.sh"
grep -q 'repack-asus208-current.sh' "$ROOT/README.md"
grep -q 'KERNEL_HOSTCFLAGS="-fcommon"' "$ROOT/config/default.env"
grep -q 'NEW_UNPACK/dtb' "$ROOT/scripts/repack-asus208-boot.sh"
grep -q 'NEW_UNPACK/second' "$ROOT/scripts/repack-asus208-boot.sh"
grep -q 'assert_geometry uboot 16384 8192' "$ROOT/scripts/repack-asus208-current.sh"
grep -q 'assert_geometry super 2011136 6373376' "$ROOT/scripts/repack-asus208-current.sh"
grep -q 'reproduce-asus208-current.sh' "$ROOT/README.md"
# Regression guard for ASUS/Rockchip resource repack: the upstream helper must
# execute from u-boot/ and copy the result back into kernel/.
grep -Fq 'cd "$SOURCE_DIR/u-boot"' "$ROOT/scripts/in-tree-build.sh"
grep -Fq './scripts/pack_resource.sh ../kernel/resource.img' "$ROOT/scripts/in-tree-build.sh"
grep -Fq 'cp -a resource.img ../kernel/resource.img' "$ROOT/scripts/in-tree-build.sh"
! grep -Fq 'u-boot/scripts/pack_resource.sh kernel/resource.img' "$ROOT/scripts/in-tree-build.sh"

# The flash payload path must not regress to packaging persistent ASUS/Tinker U-Boot/trust.
! grep -Eq 'copy_required .*image_dir/(uboot|trust)\.img' "$ROOT/scripts/in-tree-build.sh"
! grep -R --line-number 'sdboot.sh' "$ROOT/scripts" >/dev/null

printf '%s\n' 'All controller tests passed.'
