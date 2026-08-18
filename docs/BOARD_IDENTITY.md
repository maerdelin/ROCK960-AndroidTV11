# Board identity lock

This controller targets **only the original ROCK960 Model A / Model B (RK3399)**.

It does **not** target ROCK960 Model C / C1 / C2 / C4.

Locked hardware assumptions:

- SoC: Rockchip RK3399
- RAM family: LPDDR3 (Model A/B)
- Storage: onboard 16/32 GB eMMC family used by original A/B product
- Wi-Fi/Bluetooth module: **AMPAK AP6356S**
- Wi-Fi transport: SDIO
- Wi-Fi firmware family in the pinned ASUS Android 11 BSP: **BCM4356A2**
- Wi-Fi calibration/NVRAM: `nvram_ap6356s.txt`
- Bluetooth route: UART0 in the kernel board DTS
- Debug UART: UART2, 1.5 Mbps

The controller refuses to generate its Android kernel DTS from any file other than the
pinned `rk3399-rock960-ab.dts` shape. A ROCK960C port must be a separate product and must
not reuse this repository without deliberate board-specific changes.
