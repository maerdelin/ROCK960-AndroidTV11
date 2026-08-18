import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ContractTests(unittest.TestCase):
    def test_no_tinker_sdboot_in_build_path(self):
        text = (ROOT / "scripts/in-tree-build.sh").read_text()
        self.assertNotIn("sdboot.sh", text)
        self.assertIn("mkupdate_rk3399.sh", text)

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


if __name__ == "__main__":
    unittest.main()
