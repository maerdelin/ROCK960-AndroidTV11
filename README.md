# ROCK960 Android TV 11 — ASUS Tinker Board 2 Android 11 BSP Port

> Status: **v1.2.0-final — recommended first real-build controller**. This release locks the target to original ROCK960 Model A/B, fixes Wi-Fi to AP6356S, installs the AP6356S NVRAM explicitly, verifies the installed Wi-Fi payload by SHA-256, and audits the ASUS Android 11 U-Boot against the ROCK960 A/B boot-critical contract. The resulting ROM is **not claimed as hardware-validated** until a ROCK960 A/B board completes the first full build and UART/HDMI/WLAN verification.

This repository builds an AOSP Android TV 11 image for **ROCK960 Model A/B (RK3399)** by using ASUS/TinkerBoard's pinned **Tinker Board 2/2S Android 11 2.0.8** source release as the single Android/Rockchip BSP baseline, then generating a ROCK960-specific TV product and kernel device tree.

The repository is intentionally small. `repo sync` downloads the Android/Rockchip source tree at build time.

## Why this baseline

Pinned source baseline:

- manifest branch: `android11-rockchip`
- manifest: `tinker_board_2-android11-2.0.8.xml`
- release tag used by the manifest: `tinker_board_2-android11-2.0.8`
- AOSP supplement: `android-11.0.0_r46`

The ASUS manifest already includes `device/google/atv`, `device/rockchip/rk3399`, Rockchip common device code, the 4.19 kernel tree, U-Boot, RKTools, rkbin/rkst, Rockchip HALs, and Widevine L3 source/prebuilts. This avoids mixing unrelated Android releases.

## ROCK960 hardware strategy

The kernel in this exact ASUS release already contains `rk3399-rock960-ab.dts`. We preserve its board wiring instead of transplanting the Tinker Board 2 DTS. That preserves the ROCK960 definitions for:

- RK3399 + Mali-T860
- eMMC on `fe330000.sdhci`, HS400
- microSD
- AP6356S SDIO Wi-Fi wiring and host-wake (generated Android DTS corrects the historical upstream `ap6354` module label to `ap6356s`)
- Bluetooth on UART0 and its reset/wake GPIOs
- HDMI + I2S2 HDMI audio + SPDIF
- USB 2/3, USB-C OTG and FUSB302 Type-C controller
- PCIe power/control wiring
- CPU/GPU regulators, thermal policy and suspend GPIOs
- IR receiver definitions present in the board DTS

The source ROCK960 DTS inherits `rk3399-linux.dtsi`, whose `chosen` node contains a Linux `root=PARTUUID=... rootfstype=ext4 rootwait` command line and whose DRM display route is disabled. The generator creates a sibling `rk3399-rock960-android-base.dtsi`, removes the Linux root-partition arguments, corrects the generated ROCK960 Wi-Fi selector from the pinned source's historical `ap6354` label to `ap6356s`, and then generates `rk3399-rock960-ab-android.dts` with narrowly scoped Android glue: Android firmware node, VOP/MMU enablement, HDMI DDC timing, display subsystem + HDMI route, I2S2 clocking, and RNG. It deliberately does **not** replace the ROCK960 board DTS with a generic RK3399 Android board.

## Board identity and AP6356S Wi-Fi policy

This repository is **not for ROCK960C**; see `docs/BOARD_IDENTITY.md`. The controller no longer keeps the old `wifi_chip_type = "ap6354"` value in the generated ROCK960 Android DTS. ROCK960 is fixed to **AP6356S**. The generated product installs:

```text
fw_bcm4356a2_ag.bin        -> /vendor/etc/firmware/fw_bcmdhd.bin
fw_bcm4356a2_ag_apsta.bin  -> /vendor/etc/firmware/fw_bcmdhd_apsta.bin
fw_bcm4356a2_ag_p2p.bin    -> /vendor/etc/firmware/fw_bcmdhd_p2p.bin
nvram_ap6356s.txt           -> /vendor/etc/firmware/nvram.txt
```

The build verifies the four installed files byte-for-byte and by SHA-256. `nvram_ap6354.txt` is not used for the ROCK960 product. See `docs/WIFI_BT.md`.

## U-Boot policy

The build keeps the pinned ASUS Android 11 RK3399 U-Boot so Android boot/AVB/Fastboot remain internally consistent, but `audit-source.sh` now fails unless its RK3399 EVB baseline still matches the boot-critical ROCK960 A/B contract (UART2 1.5 Mbps, RK808, eMMC HS400, MMC0 Fastboot, USB). See `docs/BOOTLOADER.md`. This is a source-level compatibility check, not a substitute for the first physical UART boot.

## Android TV strategy

The generated product is `rock960_atv-userdebug`. It is cloned from Rockchip's own Android 11 `rk3399_atv` product, which already has `PRODUCT_CHARACTERISTICS := tv`; Rockchip common device configuration then inherits AOSP `device/google/atv/products/atv_base.mk`.

For first bring-up:

- GTVS/GMS/FRP/PlayReady are disabled.
- Widevine L3 remains available by default because this source release contains `vendor/widevine` and the RK3399 ATV VINTF manifest declares Widevine.
- Camera and high-speed Ethernet product features are disabled because the base ROCK960 board has no onboard camera sensor and its existing DTS has GMAC disabled. Generic RK3399 tablet gravity/light-sensor declarations and factory PCBA/stress-test features are also disabled rather than advertising hardware not present on the base board.
- AVB is **disabled by default for first boot** to remove a verification variable. Set `ENABLE_AVB=1` after the board boots reliably and rebuild.

## Biggest remaining risk

The largest remaining uncertainty is now **physical first-boot validation**, not an unaudited U-Boot source choice. The controller keeps the ASUS Android 11 RK3399 U-Boot and verifies its ROCK960 A/B boot-critical contract, but only your real board can prove SPL/DRAM/eMMC initialization and the hand-off into the ROCK960-specific Android kernel. See `docs/BOOTLOADER.md`.

For the first TV bring-up, **HDMI is the primary display target**. ROCK960 hardware also exposes USB-C DisplayPort, MIPI-DSI and MIPI-CSI, but the exact board DTS used by the ASUS 2.0.8 kernel does not explicitly enable a `cdn_dp` board route and its camera sensor nodes are disabled. The controller preserves those physical interfaces without inventing board/panel/sensor configuration; DP/DSI/camera are deliberately deferred until the HDMI base ROM boots.

## Recommended machine setup for i7-4790 / 16 GB

Use a native Linux filesystem with at least **450 GiB free**. For a 16 GiB RAM machine, create about **32 GiB swap** and keep `BUILD_JOBS=3`.

Example `config/local.env`:

```bash
cp config/local.env.example config/local.env
nano config/local.env
```

```bash
WORKSPACE="/mnt/android-build/rock960-atv11-asus"
SYNC_JOBS=4
BUILD_JOBS=3
BUILD_ENV="auto"
ENABLE_AVB=0
```

If needed:

```bash
sudo ./scripts/create-swap.sh 32G /swapfile
```

## Pre-build validation

Run these before committing to the full build:

```bash
./tests/run.sh
./scripts/doctor.sh
./scripts/network-preflight.sh
```

`network-preflight.sh` checks the exact ASUS release tags, the Android 11 AOSP tag, the pinned manifest contents, and critical RK3399/ATV/kernel/U-Boot/RKTools/vendor source references with real network requests.

## One-shot build

```bash
./scripts/one-shot.sh
```

The flow is:

1. host/disk/memory checks
2. online source-reference checks
3. `repo init` + `repo sync`
4. generate `rock960_atv`
5. generate `rk3399-rock960-ab-android.dts`
6. source/hardware contract audit, including A/B-only identity, U-Boot boot-critical checks, Linux-root bootarg removal, AP6356S selector + firmware/NVRAM mapping, camera/AVB ordering and board-interface markers
7. **real U-Boot compilation**
8. **real ROCK960 kernel + DTB compilation**
9. resolved build-variable contract check + `m nothing` Android build-graph validation
10. full Android build
11. byte-for-byte + SHA-256 verification of AP6356S Wi-Fi payload aliases
12. collect Rockchip images without ASUS/Tinker-specific `sdboot.sh`
13. call upstream `RKTools/.../mkupdate_rk3399.sh`
14. update-image and Wi-Fi SHA-256 verification

Final files:

```text
$WORKSPACE/artifacts/latest/
├── ROCK960-AndroidTV11-ASUS-2.0.8-*-update.img
├── SHA256SUMS.txt
├── WIFI-SHA256SUMS.txt
└── images/
    ├── MiniLoaderAll.bin
    ├── uboot.img
    ├── trust.img
    ├── boot.img
    ├── recovery.img
    ├── dtbo.img
    ├── vbmeta.img
    ├── super.img
    ├── parameter.txt
    └── baseparameter.img
```

## Build environment

`BUILD_ENV=auto` uses Docker when available. The supplied container is based on Ubuntu 18.04 to track ASUS's published 2.0.8 build environment and OpenJDK 8. It runs with the caller's UID/GID and bind-mounts the source/work directories.

If Docker is unavailable, set `BUILD_ENV=host` and install dependencies with:

```bash
sudo ./scripts/prepare-host.sh
```

Docker is recommended because modern host distributions have more package/version drift from this 2021-era Android BSP.


## Final audit

The final controller audit is documented in [`docs/FINAL_AUDIT.md`](docs/FINAL_AUDIT.md). It records the exact source pins, effective build-variable assertions, ROCK960 board assumptions, Wi-Fi/BT handling, packaging contract and the remaining U-Boot uncertainty.

## Safety

Do **not** flash `update.img` until you have:

- confirmed the board is ROCK960 Model A/B;
- verified a working Maskrom recovery path and `rkdeveloptool` access;
- saved anything important from eMMC;
- ideally connected the 1.5 Mbps UART console for first boot.

See `docs/FIRST_BOOT.md` and `docs/FLASHING.md`.

## Commands

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
```

The staged commands are useful if a long build fails. Re-running `make port` is idempotent and does not reset the downloaded upstream repositories.
