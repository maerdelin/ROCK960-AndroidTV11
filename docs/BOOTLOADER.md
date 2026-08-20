# Bootloader decision — ROCK960 A/B

The controller builds and audits the **ASUS/Tinker Board Android 11 2.0.8 RK3399 U-Boot**
rather than importing the old Android 7.1-era 96rocks tree into an Android 11 source chain.

However, the default **first-boot RKUpdate package does not persistently flash that
`uboot.img` or `trust.img`**. They are retained as debug/audit artifacts until the physical
ROCK960 board has completed UART/HDMI bring-up.

## Why build the ASUS Android 11 U-Boot at all?

The historical 96Boards AOSP instructions build original ROCK960 A/B with
`rock960-ab-rk3399_defconfig`. That older target captures useful board facts such as RK3399,
UART2 at 1.5 Mbps, eMMC on MMC device 0, RK808 and ROCK960/EVB-style wiring.

The pinned ASUS Android 11 `rk3399_defconfig` also contains the newer Android bootloader,
AVB/libavb, Fastboot/RKIMG and USB gadget code expected by this BSP. Building and auditing
it gives us a modern reference implementation without forcing it onto the board before
first-boot validation.

## What the source audit verifies

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

## First-boot flash policy

The first real bring-up showed that kernel/Android validation should not be coupled to a
persistent bootloader replacement. Therefore the default packer now enforces:

```text
MiniLoaderAll.bin    present as RKUpdate/RKDevTool outer download loader
uboot.img            NOT present as a persistent package payload
trust.img            NOT present as a persistent package payload
```

The compiled U-Boot and trust outputs are copied to:

```text
artifacts/latest/bootloader-debug/
```

They can be compared against UART logs or used later in a deliberately scoped bootloader
experiment, but they are not part of the default first-boot flash payload.

## Important boundary

Passing the source audit still does **not** prove the board has booted this image. The first
physical-board run should confirm over UART2 at 1.5 Mbps that the existing ROCK960 boot
chain reaches the new Android kernel, then validate HDMI/eMMC/USB/WLAN. If the failure
occurs before kernel entry, use that UART log to decide whether a minimal bootloader delta
is actually required.
