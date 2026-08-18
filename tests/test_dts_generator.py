import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/make_rock960_android_dts.py"

BASE = '''/dts-v1/;
#include "rk3399-linux.dtsi"
/ {
  model = "ROCK960 - 96boards based on Rockchip RK3399";
  compatible = "rockchip,rock960","rockchip,rk3399";
  wireless-wlan { wifi_chip_type = "ap6354"; };
  fusb0: fusb30x@22 {};
  ir: pwm-ir { compatible = "rockchip,remotectl-pwm"; };
};
&sdhci {};
&sdio0 {};
&uart0 {};
&hdmi {};
&usbdrd_dwc3_0 {};
&gpu {};
&pcie0 {};
'''

LINUX_DTSI = '''#include "rk3399-vop-clk-set.dtsi"
/ {
  chosen {
    bootargs = "earlycon=uart8250,mmio32,0xff1a0000 console=ttyFIQ0 rw root=PARTUUID=614e0000-0000 rootfstype=ext4 rootwait coherent_pool=1m";
  };
};
&display_subsystem { status = "disabled"; };
'''


class DtsTest(unittest.TestCase):
    def test_android_glue_and_linux_bootargs_sanitized(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            base = d / "rk3399-rock960-ab.dts"
            linux = d / "rk3399-linux.dtsi"
            out = d / "rk3399-rock960-ab-android.dts"
            base.write_text(BASE)
            linux.write_text(LINUX_DTSI)
            subprocess.run(["python3", str(TOOL), "--base", str(base), "--output", str(out)], check=True)

            generated_base = d / "rk3399-rock960-android-base.dtsi"
            self.assertTrue(generated_base.exists())
            sanitized = generated_base.read_text()
            text = out.read_text()

            self.assertIn('bootargs = "earlycon=uart8250,mmio32,0xff1a0000 coherent_pool=1m";', sanitized)
            self.assertNotIn("root=PARTUUID=", sanitized)
            self.assertNotIn("rootfstype=ext4", sanitized)
            self.assertIn('#include "rk3399-rock960-android-base.dtsi"', text)
            self.assertNotIn('#include "rk3399-linux.dtsi"', text)
            self.assertIn("firmware_android: android", text)
            self.assertIn("&route_hdmi", text)
            self.assertIn('wifi_chip_type = "ap6356s"', text)
            self.assertNotIn('wifi_chip_type = "ap6354"', text)
            self.assertIn('wifi_chip_type = "ap6354"', base.read_text())
            self.assertNotIn("rk3399-android.dtsi", text)


    def test_refuses_unexpected_wifi_selector_shape(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            base = d / "rk3399-rock960-ab.dts"
            linux = d / "rk3399-linux.dtsi"
            out = d / "out.dts"
            base.write_text(BASE.replace('wifi_chip_type = "ap6354"', 'wifi_chip_type = "ap6256"'))
            linux.write_text(LINUX_DTSI)
            p = subprocess.run(["python3", str(TOOL), "--base", str(base), "--output", str(out)])
            self.assertNotEqual(p.returncode, 0)

    def test_refuses_unknown_linux_bootargs(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            base = d / "rk3399-rock960-ab.dts"
            linux = d / "rk3399-linux.dtsi"
            out = d / "out.dts"
            base.write_text(BASE)
            linux.write_text('/ { chosen { bootargs = "console=ttyS0"; }; };\n')
            p = subprocess.run(["python3", str(TOOL), "--base", str(base), "--output", str(out)])
            self.assertNotEqual(p.returncode, 0)


if __name__ == "__main__":
    unittest.main()
