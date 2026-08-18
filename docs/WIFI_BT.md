# Wi-Fi and Bluetooth

ROCK960 Model A/B is treated as an **AP6356S** board in this controller. The pinned ASUS/Tinker Board 2 Android 11 kernel still carries a historical `wifi_chip_type = "ap6354"` label in `rk3399-rock960-ab.dts`; v1.2.0-final does not preserve that label in the generated Android DTS. Instead, the DTS generator rewrites only that module selector to:

```dts
wifi_chip_type = "ap6356s";
```

The original ROCK960 SDIO bus, power/reset GPIOs, host-wake interrupt, 1.8 V signaling and clock wiring are preserved unchanged.

## Firmware selection

In this exact Rockchip kernel, `drivers/net/wireless/rockchip_wlan/rkwifi/rk_wifi_config.c` requests the generic paths:

```text
/vendor/etc/firmware/fw_bcmdhd.bin
/vendor/etc/firmware/nvram.txt
```

The ASUS vendor tree also contains an AP6356S-specific NVRAM and BCM4356A2 firmware family. The generated ROCK960 product therefore creates these explicit aliases:

```text
fw_bcm4356a2_ag.bin        -> /vendor/etc/firmware/fw_bcmdhd.bin
fw_bcm4356a2_ag_apsta.bin  -> /vendor/etc/firmware/fw_bcmdhd_apsta.bin
fw_bcm4356a2_ag_p2p.bin    -> /vendor/etc/firmware/fw_bcmdhd_p2p.bin
nvram_ap6356s.txt           -> /vendor/etc/firmware/nvram.txt
```

`nvram_ap6354.txt` is not used for the ROCK960 product.

## Build-time verification

`scripts/audit-source.sh` refuses to continue unless the AP6356S NVRAM, all three BCM4356A2 firmware files, the generic bcmdhd firmware loader names and the generated copy rules are present.

After the full Android build, `scripts/in-tree-build.sh` compares every installed vendor alias byte-for-byte against its pinned source file and also compares SHA-256 hashes. Packaging writes the four final hashes to:

```text
$WORKSPACE/artifacts/latest/WIFI-SHA256SUMS.txt
```

This prevents a later product makefile from silently replacing the AP6356S NVRAM with another module's calibration data.

## Bluetooth

Bluetooth remains on the ROCK960 board's UART0 route. The board DTS reset/wake GPIOs are preserved, and the generic RK3399 ATV `bt_vendor.conf` uses `/dev/ttyS0`, matching UART0.

## First-board validation

The remaining WLAN validation point is the exact silicon/firmware revision on the physical module, not the AP6356S board identity. On first boot, capture UART/dmesg and confirm that bcmdhd probes SDIO, loads `fw_bcmdhd.bin` plus `nvram.txt`, and creates `wlan0`. Do not fall back to AP6354 NVRAM merely because the old upstream DTS carried that string.
