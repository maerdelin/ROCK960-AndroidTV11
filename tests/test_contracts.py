import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ContractTests(unittest.TestCase):
    def test_no_tinker_sdboot_in_build_path(self):
        text = (ROOT / "scripts/in-tree-build.sh").read_text()
        self.assertNotIn("sdboot.sh", text)
        self.assertIn("pack-safe-update.sh", text)
        self.assertNotIn('copy_required "$SOURCE_DIR/u-boot/uboot.img" "$image_dir/uboot.img"', text)
        self.assertNotIn('copy_required "$SOURCE_DIR/$trust" "$image_dir/trust.img"', text)

    def test_no_asus_top_level_update_build(self):
        for name in ["one-shot.sh", "build.sh", "pack.sh", "in-tree-build.sh"]:
            text = (ROOT / "scripts" / name).read_text()
            self.assertNotIn("./build.sh -u", text)

    def test_release_is_pinned(self):
        env = (ROOT / "config/default.env").read_text()
        self.assertIn('ASUS_MANIFEST_FILE="tinker_board_2-android11-2.0.8.xml"', env)
        self.assertIn('ASUS_RELEASE_TAG="tinker_board_2-android11-2.0.8"', env)
        self.assertIn('AOSP_RELEASE_TAG="android-11.0.0_r46"', env)

    def test_bringup_avb_default(self):
        env = (ROOT / "config/default.env").read_text()
        self.assertIn("ENABLE_AVB=0", env)

    def test_sync_asserts_manifest_contract(self):
        text = (ROOT / "scripts/sync.sh").read_text()
        self.assertIn('revision=\\"refs/tags/$ASUS_RELEASE_TAG\\"', text)
        self.assertIn('<include name=\\"$AOSP_RELEASE_TAG.xml\\"', text)
        self.assertIn('vendor/rockchip/common', text)
        self.assertIn('device/google/atv', text)

    def test_network_preflight_checks_board_and_vendor(self):
        text = (ROOT / "scripts/network-preflight.sh").read_text()
        self.assertIn("rk3399-rock960-ab.dts", text)
        self.assertIn("rockchip-android-vendor-rockchip-common", text)
        self.assertIn("rockchip-android-rkbin", text)
        self.assertIn("rockchip-android-rkst", text)

    def test_android_bootargs_are_audited(self):
        text = (ROOT / "scripts/audit-source.sh").read_text()
        self.assertIn("root=PARTUUID=|rootfstype=ext4|rootwait", text)
        self.assertIn("rk3399-rock960-android-base.dtsi", text)

    def test_resolved_build_contract_is_enforced(self):
        text = (ROOT / "scripts/in-tree-build.sh").read_text()
        self.assertIn("AVB config mismatch", text)
        self.assertIn("android-11.config", text)
        self.assertIn('PLATFORM_PRODUCT="$(get_build_var TARGET_BOARD_PLATFORM_PRODUCT)"', text)
        self.assertIn('[[ "$PLATFORM_PRODUCT" == "atv" ]]', text)

    def test_ap6356s_wifi_contract_is_enforced(self):
        audit = (ROOT / "scripts/audit-source.sh").read_text()
        build = (ROOT / "scripts/in-tree-build.sh").read_text()
        tool = (ROOT / "tools/port_product.py").read_text()
        self.assertIn("nvram_ap6356s.txt", audit)
        self.assertIn('wifi_chip_type[[:space:]]*=[[:space:]]*"ap6356s"', audit)
        self.assertIn(r"fw_bcmdhd\.bin", audit)
        self.assertIn(r"nvram\.txt", audit)
        self.assertIn("fw_bcm4356a2_ag.bin", tool)
        self.assertIn("nvram_ap6356s.txt", tool)
        self.assertIn("verify_wifi_payload", build)
        self.assertIn("cmp -s", build)
        self.assertIn("WIFI-SHA256SUMS.txt", build)

    def test_artifact_verifier_checks_partition_and_size(self):
        text = (ROOT / "scripts/verify-artifacts.sh").read_text()
        self.assertIn("suspiciously small", text)
        self.assertIn("0x00614000@0x00159400(super)", text)
        self.assertIn("WIFI-SHA256SUMS.txt", text)
        self.assertIn("package-file.generated contains persistent uboot/trust payloads", text)

    def test_board_identity_is_locked_to_original_ab(self):
        env = (ROOT / "config/default.env").read_text()
        readme = (ROOT / "docs/BOARD_IDENTITY.md").read_text()
        self.assertIn('TARGET_BOARD_FAMILY="rock960-ab"', env)
        self.assertIn('WIFI_MODULE="AP6356S"', env)
        self.assertIn('WIFI_FIRMWARE_FAMILY="BCM4356A2"', env)
        self.assertIn("only the original ROCK960 Model A / Model B", readme)
        self.assertIn("does **not** target ROCK960 Model C", readme)

    def test_uboot_source_contract_is_enforced(self):
        audit = (ROOT / "scripts/audit-source.sh").read_text()
        self.assertIn("audit_uboot_rock960.py", audit)
        self.assertIn("uboot-rock960-audit.txt", audit)
        self.assertIn("rock960-ab-pass", audit)


    def test_modern_host_kernel_compatibility_is_wired(self):
        env = (ROOT / "config/default.env").read_text()
        build = (ROOT / "scripts/in-tree-build.sh").read_text()
        repack = (ROOT / "scripts/repack-asus208-boot.sh").read_text()
        self.assertIn('KERNEL_HOSTCFLAGS="-fcommon"', env)
        self.assertGreaterEqual(build.count('HOSTCFLAGS="$KERNEL_HOSTCFLAGS"'), 2)
        self.assertGreaterEqual(repack.count('HOSTCFLAGS="$KERNEL_HOSTCFLAGS"'), 2)

    def test_boot_repack_is_self_contained_and_verifies_all_payloads(self):
        text = (ROOT / "scripts/repack-asus208-boot.sh").read_text()
        self.assertIn('KERNEL_CONFIG="$(get_build_var PRODUCT_KERNEL_CONFIG)"', text)
        self.assertIn('"${cfgs[@]}"', text)
        self.assertIn('cmp "$NEW_UNPACK/kernel"', text)
        self.assertIn('cmp "$NEW_UNPACK/dtb" "$COMPILED_DTB"', text)
        self.assertIn('cmp "$NEW_UNPACK/second" "$SOURCE_DIR/kernel/resource.img"', text)
        self.assertIn('ensure_workspace', text)

    def test_exact_current_repack_locks_boot_critical_geometry(self):
        text = (ROOT / "scripts/repack-asus208-current.sh").read_text()
        self.assertIn('subprocess.check_output(["sfdisk", "-d", img], text=True)', text)
        self.assertIn('entries.append(f"0x{size:08x}@0x{start:08x}({name})")', text)
        self.assertNotIn('0x00159400', text)
        self.assertIn('assert_geometry uboot 16384 8192', text)
        self.assertIn('assert_geometry trust 24576 8192', text)
        self.assertIn('assert_geometry boot 59392 81920', text)
        self.assertIn('assert_geometry super 2011136 6373376', text)
        self.assertIn('ensure_workspace', text)

    def test_source_audit_checks_the_verified_kernel_fixups(self):
        text = (ROOT / "scripts/audit-source.sh").read_text()
        self.assertIn('ROCK960 Ethernet MAC fallback fix', text)
        self.assertIn('Tinker-MCU-only panel variables guarded', text)

    def test_one_command_exact_current_reproducer_exists(self):
        text = (ROOT / "scripts/reproduce-asus208-current.sh").read_text()
        self.assertIn('apply-port.sh', text)
        self.assertIn('audit-source.sh', text)
        self.assertIn('repack-asus208-boot.sh', text)
        self.assertIn('repack-asus208-current.sh', text)


if __name__ == "__main__":
    unittest.main()
