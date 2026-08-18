# First boot checklist

For the first flash, connect the ROCK960 debug UART at **1,500,000 baud, 8N1** if possible.

Record the first boot from power-on through Android. The useful milestones are:

1. DDR/loader starts.
2. U-Boot sees eMMC.
3. Android boot command loads `boot.img`.
4. Kernel prints `Hardware name` / ROCK960 model.
5. eMMC, SDIO and USB controllers probe.
6. DRM detects HDMI and SurfaceFlinger starts.
7. `bcmdhd` probes the AP6356S SDIO device, loads the generic firmware/NVRAM aliases and creates `wlan0`.
8. Bluetooth opens `/dev/ttyS0`.
9. Android reaches launcher.

After ADB is available, capture the Wi-Fi evidence before changing any firmware files:

```bash
adb shell dmesg | grep -Ei 'bcmdhd|dhd|brcm|mmc|sdio|wlan'
adb shell ls -l /vendor/etc/firmware/fw_bcmdhd.bin \
  /vendor/etc/firmware/fw_bcmdhd_apsta.bin \
  /vendor/etc/firmware/fw_bcmdhd_p2p.bin \
  /vendor/etc/firmware/nvram.txt
adb shell ip link show wlan0
```

The controller already guarantees at build time that `nvram.txt` is byte-identical to `nvram_ap6356s.txt`. If Wi-Fi still fails, preserve the complete UART/dmesg log and diagnose the detected SDIO chip/revision rather than switching back to AP6354 calibration data.
