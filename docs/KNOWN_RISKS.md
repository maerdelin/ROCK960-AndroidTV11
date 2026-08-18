# Known risks

1. **U-Boot physical validation** — the ASUS Android 11 RK3399 U-Boot now passes an explicit ROCK960 A/B source-contract audit, but SPL/DRAM/eMMC behavior still requires first-board UART validation before this firmware can be called hardware-proven.
2. **Wi-Fi silicon/firmware revision** — the controller now fixes the ROCK960 identity to AP6356S, uses `nvram_ap6356s.txt`, and installs BCM4356A2 firmware aliases. The remaining check is whether the physical module revision accepts this exact BCM4356A2 blob cleanly; validate from bcmdhd/SDIO logs on the first board.
3. **Vendor media/GPU binaries** — same SoC and same BSP reduce risk substantially, but only real playback/SurfaceFlinger tests can validate all combinations.
4. **CEC and HDMI sink quirks** — kernel/Android CEC support is present, but TV interoperability requires hardware tests.
5. **AVB** — disabled by default for bring-up. A production-style image should re-enable AVB and establish a deliberate signing/key policy.
6. **USB-C DisplayPort / MIPI DSI/CSI** — hardware interfaces exist, but the exact ROCK960 A/B DTS used here does not provide enough board/panel/sensor enablement to claim them for the first TV image. HDMI is the bring-up display.
7. **Model C** — this repository targets ROCK960 Model A/B DTS only.
8. **Google certification** — AOSP Android TV is not the same as a Google-certified Android TV/Google TV product; GMS is intentionally not included.
