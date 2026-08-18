import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/port_product.py"


class PortProductTest(unittest.TestCase):
    def _fixture(self, root: Path) -> Path:
        p = root / "device/rockchip/rk3399/rk3399_atv"
        (p / "overlay").mkdir(parents=True)
        (p / "rk3399_atv.mk").write_text(
            "PRODUCT_SHIPPING_API_LEVEL := 29\n"
            "PRODUCT_BOOT_DEVICE := fe330000.sdhci\n"
            "include device/rockchip/rk3399/rk3399_atv/BoardConfig.mk\n"
            "$(call inherit-product, device/rockchip/rk3399/rk3399_atv/device.mk)\n"
            "$(call inherit-product, device/rockchip/common/device.mk)\n"
            "PRODUCT_CHARACTERISTICS := tv\n"
            "PRODUCT_NAME := rk3399_atv\nPRODUCT_DEVICE := rk3399_atv\n"
            "PRODUCT_BRAND := rockchip\nPRODUCT_MODEL := rk3399_atv\nPRODUCT_MANUFACTURER := rockchip\n"
        )
        (p / "BoardConfig.mk").write_text(
            "include device/rockchip/rk3399/BoardConfig.mk\n"
            "PRODUCT_KERNEL_DTS := rk3399-sapphire\nPRODUCT_KERNEL_CONFIG := rockchip_defconfig android-10.config\n"
            "PRODUCT_USE_PREBUILT_GTVS := yes\nBUILD_WITH_GOOGLE_FRP := true\n"
            "BUILD_WITH_GOOGLE_GMS_EXPRESS := false\nBUILD_WITH_MICROSOFT_PLAYREADY :=true\n"
            "BOARD_WIDEVINE_OEMCRYPTO_LEVEL := 3\nBOARD_AVB_ENABLE := true\n"
        )
        (p / "AndroidProducts.mk").write_text(
            "PRODUCT_MAKEFILES := $(LOCAL_DIR)/rk3399_atv.mk\n"
            "COMMON_LUNCH_CHOICES := rk3399_atv-userdebug\n"
        )
        (p / "device.mk").write_text("LOCAL_PATH := device/rockchip/rk3399/rk3399_atv\n")
        (p / "parameter.txt").write_text("MACHINE: 3399\nTYPE: GPT\n")
        (p / "bt_vendor.conf").write_text("UartPort = /dev/ttyS0\n")
        (p / "manifest.xml").write_text("<manifest/>\n")
        return p

    def test_port_bringup_defaults(self):
        with tempfile.TemporaryDirectory() as td:
            src = Path(td)
            self._fixture(src)
            subprocess.run([
                "python3", str(TOOL), "--source", str(src), "--product", "rock960_atv",
                "--avb", "0", "--camera", "0", "--ethernet", "0"
            ], check=True)
            out = src / "device/rockchip/rk3399/rock960_atv"
            self.assertTrue((out / "rock960_atv.mk").exists())
            mk = (out / "rock960_atv.mk").read_text()
            board = (out / "BoardConfig.mk").read_text()
            products = (out / "AndroidProducts.mk").read_text()
            device = (out / "device.mk").read_text()
            self.assertIn("PRODUCT_NAME := rock960_atv", mk)
            self.assertIn("PRODUCT_KERNEL_DTS := rk3399-rock960-ab-android", board)
            self.assertIn("BOARD_AVB_ENABLE := false", board)
            self.assertIn("BOARD_HS_ETHERNET := false", board)
            self.assertIn("BOARD_GRAVITY_SENSOR_SUPPORT := false", board)
            self.assertIn("BOARD_LIGHT_SENSOR_SUPPORT := false", board)
            self.assertIn("TARGET_ROCKCHIP_PCBATEST := false", board)
            self.assertIn("BOARD_HAS_STRESSTEST_APP := false", board)
            self.assertIn("BOARD_CAMERA_SUPPORT := false", board)
            self.assertIn("PRODUCT_SUPPORTS_CAMERA := false", mk)
            self.assertLess(
                mk.index("PRODUCT_SUPPORTS_CAMERA := false"),
                mk.index("$(call inherit-product, device/rockchip/rk3399/rock960_atv/device.mk)"),
            )
            self.assertIn("rock960_atv-userdebug", products)
            self.assertNotIn("rk3399_atv-userdebug", products)
            self.assertIn("fw_bcm4356a2_ag.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcmdhd.bin", device)
            self.assertIn("fw_bcm4356a2_ag_apsta.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcmdhd_apsta.bin", device)
            self.assertIn("fw_bcm4356a2_ag_p2p.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/fw_bcmdhd_p2p.bin", device)
            self.assertIn("nvram_ap6356s.txt:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/nvram.txt", device)
            self.assertNotIn("nvram_ap6354", device)
            self.assertEqual((out / "parameter.txt").read_text(), "MACHINE: 3399\nTYPE: GPT\n")

    def test_camera_enable_is_also_early(self):
        with tempfile.TemporaryDirectory() as td:
            src = Path(td)
            self._fixture(src)
            subprocess.run([
                "python3", str(TOOL), "--source", str(src), "--product", "rock960_atv",
                "--camera", "1"
            ], check=True)
            mk = (src / "device/rockchip/rk3399/rock960_atv/rock960_atv.mk").read_text()
            self.assertIn("PRODUCT_SUPPORTS_CAMERA := true", mk)
            self.assertLess(
                mk.index("PRODUCT_SUPPORTS_CAMERA := true"),
                mk.index("$(call inherit-product, device/rockchip/rk3399/rock960_atv/device.mk)"),
            )


if __name__ == "__main__":
    unittest.main()
