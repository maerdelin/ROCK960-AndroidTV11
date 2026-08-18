import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/audit_uboot_rock960.py"

DEFCONFIG = '''CONFIG_ROCKCHIP_RK3399=y
CONFIG_DEFAULT_DEVICE_TREE="rk3399-evb"
CONFIG_ANDROID_BOOTLOADER=y
CONFIG_ANDROID_AVB=y
CONFIG_FASTBOOT_FLASH=y
CONFIG_FASTBOOT_FLASH_MMC_DEV=0
CONFIG_MMC_SDHCI=y
CONFIG_MMC_SDHCI_ROCKCHIP=y
CONFIG_PMIC_RK8XX=y
CONFIG_BAUDRATE=1500000
CONFIG_DEBUG_UART_BASE=0xFF1A0000
CONFIG_USB_DWC3=y
CONFIG_USB_GADGET_DOWNLOAD=y
'''

DTS = '''/dts-v1/;
#include <dt-bindings/gpio/gpio.h>
#include "rk3399-sdram-lpddr3-4GB-1600.dtsi"
/ {
  vcc5v0_host: vcc5v0-host-en { gpio = <&gpio4 25 GPIO_ACTIVE_HIGH>; };
};
rk808: pmic@1b {};
&uart2 { status = "okay"; };
&sdhci {
  bus-width = <8>;
  mmc-hs400-1_8v;
  mmc-hs400-enhanced-strobe;
  non-removable;
};
&usb_host0_ehci {};
&usb_host0_ohci {};
&usb_host1_ehci {};
&usb_host1_ohci {};
&usbdrd_dwc3_0 {};
'''


class UBootAuditTests(unittest.TestCase):
    def _fixture(self, root: Path):
        cfg = root / "configs"
        dts = root / "arch/arm/dts"
        cfg.mkdir(parents=True)
        dts.mkdir(parents=True)
        (cfg / "rk3399_defconfig").write_text(DEFCONFIG)
        (dts / "rk3399-evb.dts").write_text(DTS)

    def test_passes_expected_rock960_ab_contract(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td) / "u-boot"
            self._fixture(root)
            report = Path(td) / "report.txt"
            p = subprocess.run([
                "python3", str(TOOL), "--u-boot", str(root), "--report", str(report)
            ], capture_output=True, text=True)
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertIn("board_family=ROCK960 Model A/B", report.read_text())
            self.assertIn("android_avb=yes", report.read_text())

    def test_rejects_wrong_emmc_contract(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td) / "u-boot"
            self._fixture(root)
            dts = root / "arch/arm/dts/rk3399-evb.dts"
            dts.write_text(dts.read_text().replace("mmc-hs400-1_8v;", ""))
            p = subprocess.run([
                "python3", str(TOOL), "--u-boot", str(root)
            ], capture_output=True, text=True)
            self.assertNotEqual(p.returncode, 0)
            self.assertIn("mmc-hs400-1_8v", p.stderr + p.stdout)


if __name__ == "__main__":
    unittest.main()
