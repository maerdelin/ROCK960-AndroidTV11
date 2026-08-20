# ROCK960 Android TV 11 — ASUS Tinker Board 2 Android 11 BSP Port

> Status: **v1.2.0-final + 2026-08-20 bring-up closure on `fix/rock960-kernel-build-fixups`**.
> The controller is source-complete for the ROCK960 A/B port changes validated during the
> first real kernel build. Physical board boot/hardware validation is still required before
> calling the ROM production-ready.

This repository builds Android TV 11 for **ROCK960 Model A/B (RK3399)** from the pinned
ASUS/Tinker Board 2 Android 11 **2.0.8** BSP. It generates a ROCK960-specific Android
product and device tree while preserving the ROCK960 A/B board wiring already present in
the exact ASUS kernel release.

## Pinned baseline

- manifest branch: `android11-rockchip`
- manifest: `tinker_board_2-android11-2.0.8.xml`
- release tag: `tinker_board_2-android11-2.0.8`
- AOSP supplement: `android-11.0.0_r46`

The ASUS manifest supplies Rockchip Android 11 framework/device code, RK3399 HALs, 4.19
kernel, U-Boot, RKTools, rkbin/rkst and Widevine L3 components from one internally
consistent BSP generation.

## 2026-08-20 verified bring-up closure

The first real ROCK960 kernel build exposed three source issues which are now permanently
wired into the controller instead of being manual local edits:

1. `rk3399-rock960-ab-android.dts` removes the stale ASUS `&vpu` node which does not exist
   in this kernel's symbol set (`vdpu`/`vepu`/`vpu_mmu` are used instead).
2. `panel-simple.c` keeps two Tinker-MCU-only variables behind `CONFIG_TINKER_MCU`, fixing
   the warnings-as-errors build on ROCK960.
3. `eth_mac_tinker.c` no longer forces the Tinker Board AT24 EEPROM MAC path on ROCK960;
   it leaves the MAC invalid so the normal stmmac/platform fallback can supply it.

The exact kernel diff is stored in:

```text
patches/rock960-kernel-build-fixups.patch
```

`make port` now calls `scripts/apply-kernel-fixups.sh`. The helper is idempotent: it applies
the patch only to the expected clean ASUS 2.0.8 kernel tree, accepts an already-patched
tree, and aborts on an unexpected third state.

## ROCK960 hardware strategy

The generated Android DTS is based on ASUS's pinned `rk3399-rock960-ab.dts`, not the
Tinker Board 2 DTS. This preserves ROCK960 definitions for:

- RK3399 + Mali-T860;
- eMMC/HS400 and microSD;
- AP6356S SDIO Wi-Fi wiring and host-wake;
- Bluetooth on UART0 and reset/wake GPIOs;
- HDMI, I2S2 HDMI audio and SPDIF;
- USB 2/3, USB-C OTG and FUSB302 Type-C controller;
- PCIe power/control wiring;
- CPU/GPU regulators, thermal policy and suspend GPIOs;
- IR definitions present in the original ROCK960 DTS.

The Android DTS generator removes Linux root-partition bootargs, corrects the historical
`wifi_chip_type = "ap6354"` label to `ap6356s`, removes the stale `&vpu` block and adds only
narrow Android display/firmware glue (firmware node, VOP/MMU, HDMI route/DDC timing, I2S2
clocking and RNG).

## AP6356S Wi-Fi policy

ROCK960 A/B is fixed to **AP6356S**. The generated product installs:

```text
fw_bcm4356a2_ag.bin        -> /vendor/etc/firmware/fw_bcmdhd.bin
fw_bcm4356a2_ag_apsta.bin  -> /vendor/etc/firmware/fw_bcmdhd_apsta.bin
fw_bcm4356a2_ag_p2p.bin    -> /vendor/etc/firmware/fw_bcmdhd_p2p.bin
nvram_ap6356s.txt           -> /vendor/etc/firmware/nvram.txt
```

The full Android build verifies these four installed files byte-for-byte and by SHA-256.

## Bootloader and first-boot packaging policy

The controller still **builds and audits** the pinned ASUS Android 11 RK3399 U-Boot so its
Android/Fastboot/AVB compatibility can be inspected. However, after the 2026-08-20 real
bring-up, the default RKUpdate package follows the safer first-boot policy used for the
validated test image:

- `MiniLoaderAll.bin` is present as the RKUpdate/RKDevTool outer download loader;
- `uboot.img` is **not** a persistent flash payload;
- `trust.img` is **not** a persistent flash payload;
- compiled U-Boot/trust files are retained separately under `bootloader-debug/` for UART
  comparison and later controlled bootloader work.

`scripts/pack-safe-update.sh` generates the package-file from only the images that are
actually meant to be flashed, rejects accidental `uboot.img`/`trust.img` payloads, packs
with ASUS 2.0.8 `afptool` + `rkImageMaker`, then unpacks the inner firmware and verifies
`boot.img` byte-for-byte before accepting the result.

This matches the safety policy used by the working 2026-08-20 test-package workflow.

## Exact reproduction of the 2026-08-20 minimal test workflow

The full source build produces the ROCK960 Android TV product. For regression/debugging,
two scripts also preserve the exact **minimal ASUS-2.0.8-user-space + ROCK960-boot** path
used during the first bring-up.

First repack the official ASUS raw image's boot partition around the compiled ROCK960
kernel/DTB/resource:

```bash
./scripts/repack-asus208-boot.sh \
  --firmware /path/Tinker_Board_2-Android11-v2.0.8-20220503.img \
  --out /path/rock960-test-boot.img
```

The script verifies:

- ASUS ramdisk is byte-identical;
- boot header version, OS version/patch level and command line are preserved;
- the new boot contains the compiled ROCK960 `Image`;
- the original ASUS kernel was actually replaced.

Then reproduce the safe RKDevTool `update.img` using the official ASUS Android partitions
and that verified boot image:

```bash
./scripts/repack-asus208-current.sh \
  --firmware /path/Tinker_Board_2-Android11-v2.0.8-20220503.img \
  --boot /path/rock960-test-boot.img \
  --out /path/ROCK960-Android11-v2.0.8-update.img
```

This extracts `misc`, `dtbo`, `vbmeta`, `recovery`, `baseparameter` and `super` from the
official ASUS raw GPT image, derives `parameter.txt` from that same GPT, inserts the
verified ROCK960 boot and calls the same safe packer used by the normal build. It does not
include persistent U-Boot/trust payloads.

Exact binary SHA-256 values can differ across independent Android builds because generated
outputs/timestamps may differ. The source/partition/boot policy is what is kept identical.

For a single command that rebuilds the kernel/DTB/resource and then reproduces this exact-current package path from the official ASUS raw image, run:

```bash
./scripts/reproduce-asus208-current.sh \
  --firmware /path/Tinker_Board_2-Android11-v2.0.8-20220503.img \
  --out /path/ROCK960-Android11-v2.0.8-update.img
```

This is the closest reproducible equivalent of the 2026-08-20 3.2 GiB test image. `one-shot.sh` remains the full source-built Android TV path and is intentionally not claimed to be byte-identical to that minimal official-ASUS-partitions image.

## Android TV product policy

The generated product is `rock960_atv-userdebug`, cloned from Rockchip's Android 11
`rk3399_atv` product. For first bring-up:

- GTVS/GMS/FRP/PlayReady are disabled;
- Widevine L3 remains available by default;
- camera and high-speed Ethernet product features remain disabled until validated;
- generic sensors/factory features not present on ROCK960 are not advertised;
- AVB is disabled by default to remove a first-boot variable.

HDMI is the primary first-boot display target. USB-C DisplayPort, MIPI-DSI and MIPI-CSI are
not claimed as validated and are intentionally deferred.

## Build environment

A native Linux filesystem with at least **450 GiB free** is recommended. For a 16 GiB RAM
machine, use about **32 GiB swap** and `BUILD_JOBS=3`.

Example `config/local.env`:

```bash
WORKSPACE="/mnt/android-build/rock960-atv11-asus"
SYNC_JOBS=4
BUILD_JOBS=3
BUILD_ENV="auto"
ENABLE_AVB=0
```

Docker is recommended because the supplied image tracks ASUS's older Ubuntu/OpenJDK build
environment more closely than a modern host distribution.

## Validation and build

Before a full build:

```bash
./tests/run.sh
./scripts/doctor.sh
./scripts/network-preflight.sh
```

One-shot build:

```bash
./scripts/one-shot.sh
```

The flow is:

1. host/disk/memory checks;
2. pinned online source checks;
3. `repo init` + `repo sync`;
4. apply the verified kernel build-fix patch idempotently;
5. generate `rock960_atv`;
6. generate `rk3399-rock960-ab-android.dts`;
7. source/hardware/U-Boot contract audit;
8. real U-Boot compilation for validation/debug artifacts;
9. real ROCK960 kernel + DTB compilation;
10. Android build-graph validation and full Android build;
11. AP6356S firmware/NVRAM verification;
12. collect Android flash payloads;
13. generate safe RKUpdate package with `pack-safe-update.sh` (no persistent U-Boot/trust);
14. verify update image, package policy and SHA-256 files.

Final files:

```text
$WORKSPACE/artifacts/latest/
├── ROCK960-AndroidTV11-ASUS-2.0.8-*-update.img
├── SHA256SUMS.txt
├── WIFI-SHA256SUMS.txt
├── images/
│   ├── MiniLoaderAll.bin
│   ├── boot.img
│   ├── recovery.img
│   ├── dtbo.img
│   ├── vbmeta.img
│   ├── misc.img
│   ├── super.img
│   ├── parameter.txt
│   ├── baseparameter.img
│   └── package-file.generated
└── bootloader-debug/
    ├── uboot.img
    ├── trust.img
    └── idbloader.img        # when produced by the U-Boot build
```

## Safety

Do **not** flash `update.img` until you have:

- confirmed the board is original ROCK960 Model A/B, not ROCK960C;
- verified a working Maskrom recovery path and RKDevTool/rkdeveloptool access;
- saved anything important from eMMC;
- ideally connected UART2 at 1.5 Mbps for the first boot.

A failed Android/kernel/partition flash is expected to be recoverable through RK3399
Maskrom when the board/USB/eMMC hardware itself remains healthy, but that is not a reason
to skip recovery preparation.

## Useful staged commands

```bash
make doctor
make network
make sync
make port
make audit
make preflight
make build
make pack
make verify
make test
```

See `docs/FINAL_AUDIT.md`, `docs/BOOTLOADER.md`, `docs/FIRST_BOOT.md`, `docs/FLASHING.md` and
`docs/BRINGUP_2026-08-20.md` for the audit trail and current limitations.
