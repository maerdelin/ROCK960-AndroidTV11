# Final controller audit

This document records what is deliberately checked before the first real ROCK960 build.

## Pinned source contract

The controller requires the ASUS/Tinker Board 2/2S Android 11 release manifest
`tinker_board_2-android11-2.0.8.xml`, release tag `tinker_board_2-android11-2.0.8`,
and AOSP supplement `android-11.0.0_r46`.

Before `repo sync`, `scripts/network-preflight.sh` performs real Git/HTTP checks for the
manifest and the critical RK3399/ATV/kernel/U-Boot/RKTools/rkbin/rkst/vendor repositories.
`scripts/sync.sh` then validates the checked-out manifest before the expensive sync begins.

## Product contract

The generated product is cloned from the Rockchip `rk3399_atv` product. The controller
asserts at build time that:

- the resolved product route is `atv`;
- dynamic partitions are enabled;
- the target kernel DTS is `rk3399-rock960-ab-android`;
- the effective kernel configuration contains `rockchip_defconfig`, `android-10.config`,
  and the Android 11 common fragment `android-11.config`;
- the effective AVB value equals the controller setting;
- camera and Ethernet product policies equal the controller settings;
- generic RK3399 tablet sensor advertisements and Rockchip factory PCBA/stress-test features are disabled for the base ROCK960 TV product.

The camera policy is set before Rockchip inherits AOSP ATV because AOSP ATV uses a guarded
`PRODUCT_SUPPORTS_CAMERA ?= true`; setting it after the inherit would be too late.

## ROCK960 board contract

The board source is the `rk3399-rock960-ab.dts` already present in the exact ASUS 2.0.8
kernel tag. The port keeps that board wiring for regulators, eMMC/SD, SDIO WLAN, UART0
Bluetooth, HDMI/audio, USB/Type-C/FUSB302, PCIe, GPU, thermal policy and IR.

That upstream board DTS inherits `rk3399-linux.dtsi`, whose chosen bootargs contain a Linux
root partition and whose DRM display route is disabled. The generator therefore makes a
sibling Android base DTSI, removes only the Linux root bootargs, and adds narrowly scoped
Android display/firmware glue. It does not replace the ROCK960 board DTS with a generic
RK3399 Android board.

The source audit refuses to proceed if the expected board markers or the exact Linux
bootargs shape have changed.

## Wi-Fi / Bluetooth

ROCK960 Model A/B is treated as an AP6356S board. The pinned ASUS kernel source still
contains the historical `wifi_chip_type = "ap6354"` string in the upstream ROCK960 DTS,
but the Android DTS generator rewrites that one module identity field to
`wifi_chip_type = "ap6356s"` while preserving SDIO, host-wake, power/reset GPIO and clock
wiring. The upstream source file itself is not modified.

The same pinned kernel's `rkwifi/rk_wifi_config.c` requests the generic vendor filenames
`fw_bcmdhd.bin` and `nvram.txt`. The generated ROCK960 product maps the release's
`fw_bcm4356a2_ag.bin`, `fw_bcm4356a2_ag_apsta.bin`, and `fw_bcm4356a2_ag_p2p.bin` to
generic bcmdhd aliases and maps `nvram_ap6356s.txt` to `nvram.txt`. `nvram_ap6354.txt` is
not part of the ROCK960 product mapping.

The source audit verifies those files and copy rules before build. After the Android build,
the controller compares each installed alias byte-for-byte and by SHA-256 against its
source file; packaging emits `WIFI-SHA256SUMS.txt`. UART0 and the ROCK960 Bluetooth
reset/wake GPIO definitions remain preserved.

The remaining real-hardware validation point is the exact BCM4356-family silicon/firmware
revision reported by the physical module. A failure after the AP6356S mapping should be
diagnosed from SDIO/bcmdhd logs rather than by reverting to AP6354 calibration data.

## Display / media / audio

The RK3399 ATV userspace remains the ASUS/Rockchip Android 11 stack (Mali-T860, HWC/DRM,
MPP/VPU/OMX and audio HAL). The ROCK960 kernel board wiring remains board-specific. The
Android glue enables VOP/VOP-MMU, the display subsystem and HDMI route, applies the RK3399
Android HDMI DDC timings, sets I2S2 `bclk-fs = 128`, and enables RNG.

## Partition and packaging contract

The RK3399 ATV `parameter.txt` is preserved. The controller audits its `super` and growing
`userdata` entries. Packaging intentionally does not call ASUS/Tinker-specific `sdboot.sh`.
Instead it copies the same essential image set used by the upstream Rockchip image assembly
and invokes the release's `RKTools/.../mkupdate_rk3399.sh` with its upstream `package-file`.

The finished artifact verifier checks the SHA-256, required component images, the audited
partition map and a minimum update-image size.

## Known hardware risk: U-Boot

The ASUS Android 11 `rk3399_defconfig` is Android/AVB capable but its default U-Boot device
tree is `rk3399-evb`, not a dedicated ROCK960 target. The controller intentionally does not
replace it with the much older 96rocks U-Boot wholesale because that would mix boot chains.

This is the largest remaining first-boot uncertainty. A failure before the kernel banner on
the 1.5 Mbps UART should be treated as a U-Boot board-port task: retain the ASUS Android 11
boot/AVB implementation and port only ROCK960-specific U-Boot board/DT pieces.

## Release status

`v1.2.0-final` supersedes `v1.0.0-final` and incorporates the AP6356S Wi-Fi identity/NVRAM
correction plus post-build Wi-Fi payload verification. It is recommended for the first
real full build. The resulting ROM is still not claimed as hardware-validated until a
physical ROCK960 completes the build/flash/UART/HDMI/WLAN checks.

## Deliberately deferred interfaces

ROCK960 hardware documentation also exposes USB-C DisplayPort 1.2, MIPI-DSI and MIPI-CSI.
The exact `rk3399-rock960-ab.dts` used by this release does not provide an explicit board
`&cdn_dp` enable override, and the camera sensor nodes in that DTS are disabled. The first
TV bring-up therefore treats **HDMI as the primary display target** and does not invent a
USB-C DP, DSI panel, or camera configuration. USB-C data/OTG, FUSB302, PCIe and the existing
board-level CSI/DSI wiring are left intact so those interfaces can be enabled later with
hardware-specific overlays after the base ROM boots.

- U-Boot source-contract auditor checks UART2 1.5 Mbps, RK808, eMMC HS400, MMC0 Fastboot, USB and Android/AVB capabilities against the pinned ASUS Android 11 RK3399 U-Boot.
