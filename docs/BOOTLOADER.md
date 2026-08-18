# Bootloader decision — ROCK960 A/B

The controller uses the **ASUS/TinkerBoard Android 11 2.0.8 RK3399 U-Boot** rather than
copying the old Android 7.1-era 96rocks U-Boot into a modern Android 11 image chain.

## Why

The historical 96Boards AOSP instructions build original ROCK960 A/B with
`rock960-ab-rk3399_defconfig`. That old target selects RK3399, UART2 at 1.5 Mbps, eMMC on
MMC device 0, an RK808 PMIC and a ROCK960/EVB-style RK3399 device tree.

The pinned ASUS Android 11 `rk3399_defconfig` keeps those boot-critical RK3399 facilities
and additionally carries the Android 11-era Android bootloader, AVB/libavb, modern
Fastboot/RKIMG and USB gadget path. Replacing it wholesale with the old tree would throw
away exactly the newer boot-chain code this port needs.

## What v1.2.0-final verifies

`scripts/audit-source.sh` runs `tools/audit_uboot_rock960.py` and refuses to continue unless
the synced ASUS U-Boot still contains the ROCK960 A/B boot-critical contract:

- RK3399 target and `rk3399-evb` U-Boot DTS;
- UART2 debug at 1,500,000 baud and debug base `0xFF1A0000`;
- RK808 PMIC;
- eMMC SDHCI, 8-bit, HS400 1.8 V, enhanced strobe, non-removable;
- Fastboot on MMC device 0;
- RK3399 USB host/DWC3 paths and the 5 V host-enable GPIO used by the legacy ROCK960 tree;
- Android bootloader + AVB support in U-Boot.

The audit writes `artifacts/audit/uboot-rock960-audit.txt`.

## Important boundary

Passing this source audit does **not** mean the board has already booted this image. The
first physical-board run must still confirm, over UART2 at 1.5 Mbps, that SPL/U-Boot sees
the correct DRAM and eMMC and reaches the Android kernel. If it fails before kernel entry,
use that UART log to make the smallest possible U-Boot delta while keeping the ASUS
Android 11 boot/AVB implementation.
