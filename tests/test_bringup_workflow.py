import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPLY_FIXUPS = ROOT / "scripts/apply-kernel-fixups.sh"
PACK_SAFE = ROOT / "scripts/pack-safe-update.sh"


def run(cmd, *, env=None, cwd=None, check=True):
    return subprocess.run(
        cmd,
        cwd=cwd,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=check,
    )


class BringupWorkflowFunctionalTests(unittest.TestCase):
    def _env_for_home(self, home: Path):
        env = os.environ.copy()
        env["HOME"] = str(home)
        env.pop("ROCK960_IN_CONTAINER", None)
        return env

    def test_kernel_fixups_apply_and_are_idempotent(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            kernel = home / "android/rock960-atv11-asus/source/kernel"
            (kernel / "drivers/gpu/drm/panel").mkdir(parents=True)
            (kernel / "drivers/net/ethernet/stmicro/stmmac").mkdir(parents=True)

            panel = kernel / "drivers/gpu/drm/panel/panel-simple.c"
            panel.write_text(
                '''static int panel_simple_enable(struct drm_panel *panel)
{
\tstruct panel_simple *p = to_panel_simple(panel);
\tstatic bool the_first_time_rpi_enable = true;
\tint err = 0;

\tprintk("panel_simple_enable p->enabled=%d\\n", p->enabled);
}

static int panel_simple_dsi_probe(struct mipi_dsi_device *dsi)
{
\tstruct panel_desc_dsi *d;
\tconst struct of_device_id *id;
\tint err;
\tint dsi_id;

\tprintk("panel_simple_dsi_probe+\\n");
\tid = of_match_node(dsi_of_match, dsi->dev.of_node);
}
'''
            )

            eth = kernel / "drivers/net/ethernet/stmicro/stmmac/eth_mac_tinker.c"
            eth.write_text(
                '''\nint eth_mac_eeprom(u8 *eth_mac)
{
\tint i;
\tmemset(eth_mac, 0, 6);
\tprintk("Read the Ethernet MAC address from EEPROM:");
\tat24_read_eeprom(eth_mac, 0, 6);
\tfor(i=0; i<5; i++)
\t\tprintk("%2.2x:", eth_mac[i]);
\tprintk("%2.2x\\n", eth_mac[i]);

\treturn 0;
}
'''
            )

            run(["git", "init", "-q", str(kernel)])
            env = self._env_for_home(home)

            first = run(["bash", str(APPLY_FIXUPS)], env=env)
            self.assertIn("kernel fixups verified", first.stdout)
            self.assertIn("#if defined(CONFIG_TINKER_MCU)", panel.read_text())
            self.assertIn("ROCK960 does not use the Tinker Board AT24 EEPROM", eth.read_text())

            second = run(["bash", str(APPLY_FIXUPS)], env=env)
            self.assertIn("already applied", second.stdout)
            self.assertIn("kernel fixups verified", second.stdout)

    def test_safe_pack_success_and_rejects_persistent_bootloader_payloads(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            source = home / "android/rock960-atv11-asus/source"
            rockdev = source / "RKTools/linux/Linux_Pack_Firmware/rockdev"
            rkbin = source / "rkbin"
            image = home / "image"
            out = home / "update.img"
            rockdev.mkdir(parents=True)
            (rkbin / "tools").mkdir(parents=True)
            (rkbin / "RKBOOT").mkdir(parents=True)
            image.mkdir()

            (rkbin / "RKBOOT/RK3399MINIALL.ini").write_text(
                "[CHIP_NAME]\nNAME=RK330C\n[OUTPUT]\nPATH=rk3399_loader_v1.27.126.bin\n"
            )

            boot_merger = rkbin / "tools/boot_merger"
            boot_merger.write_text(
                '#!/bin/bash\nset -e\nprintf loader > rk3399_loader_v1.27.126.bin\n'
            )

            generator = rockdev / "gen-package-file.sh"
            generator.write_text(
                '''#!/bin/bash
set -e
img=$1
printf '# NAME\\tRelative path\\n'
printf 'package-file\\tpackage-file\\n'
printf 'bootloader\\t%s/MiniLoaderAll.bin\\n' "$img"
printf 'parameter\\t%s/parameter.txt\\n' "$img"
for n in misc boot dtbo vbmeta recovery baseparameter super; do
  [ -f "$img/$n.img" ] && printf '%s\\t%s/%s.img\\n' "$n" "$img" "$n"
done
printf 'backup      RESERVED\\n'
'''
            )

            afptool = rockdev / "afptool"
            afptool.write_text(
                '''#!/bin/bash
set -e
case "$1" in
  -pack) tar -cf "$3" -C "$2" Image/boot.img ;;
  -unpack) mkdir -p "$3"; tar -xf "$2" -C "$3" ;;
  *) exit 2 ;;
esac
'''
            )

            rkimage = rockdev / "rkImageMaker"
            rkimage.write_text(
                '#!/bin/bash\nset -e\ncat "$2" "$3" > "$4"\n'
            )

            for p in [boot_merger, generator, afptool, rkimage]:
                p.chmod(0o755)

            for name in ["boot", "misc", "dtbo", "vbmeta", "recovery", "baseparameter", "super"]:
                (image / f"{name}.img").write_bytes((name + "-payload").encode())
            (image / "parameter.txt").write_text(
                "TYPE: GPT\nCMDLINE:mtdparts=rk29xxnand:"
                "0x100@0x100(misc),0x100@0x200(boot),0x100@0x300(dtbo),"
                "0x100@0x400(vbmeta),0x100@0x500(recovery),"
                "0x100@0x600(baseparameter),0x100@0x700(super),-@0x800(userdata:grow)\n"
            )

            env = self._env_for_home(home)
            good = run(["bash", str(PACK_SAFE), str(image), str(out)], env=env)
            self.assertIn("safe RKUpdate package verified", good.stdout)
            self.assertTrue(out.is_file())
            self.assertTrue(Path(str(out) + ".sha256").is_file())
            pkg = (image / "package-file.generated").read_text()
            self.assertIn("boot\t", pkg)
            self.assertIn("super\t", pkg)
            self.assertNotIn("\nuboot\t", "\n" + pkg)
            self.assertNotIn("\ntrust\t", "\n" + pkg)

            (image / "uboot.img").write_bytes(b"forbidden")
            bad = run(
                ["bash", str(PACK_SAFE), str(image), str(home / "bad.img")],
                env=env,
                check=False,
            )
            self.assertNotEqual(bad.returncode, 0)
            self.assertIn("refusing to package persistent uboot.img", bad.stdout)


if __name__ == "__main__":
    unittest.main()
