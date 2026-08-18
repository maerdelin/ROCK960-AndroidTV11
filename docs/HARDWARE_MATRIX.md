# ROCK960 hardware matrix

The primary board description is the `rk3399-rock960-ab.dts` found in the same ASUS 2.0.8 kernel tag. The controller audits the following before full build.

| Function | ROCK960 source definition | Port action |
|---|---|---|
| SoC | RK3399 | keep RK3399 BSP/HAL |
| GPU | Mali-T860 | keep Rockchip Mali/HWC/RGA stack |
| eMMC | SDHCI, 8-bit, HS400 1.8 V | keep board DTS; `PRODUCT_BOOT_DEVICE=fe330000.sdhci` |
| microSD | SDMMC 4-bit | keep board DTS |
| Wi-Fi | AP6356S over SDIO; pinned upstream DTS contains historical `ap6354` label | preserve SDIO/GPIO/clock wiring; generate selector `ap6356s`; map BCM4356A2 firmware + `nvram_ap6356s.txt` to bcmdhd generic names |
| Bluetooth | Broadcom platform data, UART0 | preserve DTS; generic ATV `bt_vendor.conf` uses `/dev/ttyS0` |
| HDMI | DW HDMI | enable Android DRM route and DDC timing |
| HDMI audio | I2S2 simple-audio-card | preserve codec; add Android bclk-fs=128 |
| SPDIF | enabled in ROCK960 DTS | preserve |
| USB-C data/OTG | FUSB302 at I2C address 0x22 | preserve extcon/OTG wiring |
| USB-C DisplayPort | hardware supports DP 1.2, but exact board DTS has no explicit `&cdn_dp` enable override | defer until HDMI base boot; do not guess a DP route |
| MIPI DSI/CSI | exposed by ROCK960 connectors; camera sensor examples are disabled in DTS | preserve wiring; defer panel/sensor-specific enablement |
| USB host | EHCI/OHCI + DWC3 | preserve |
| PCIe | board regulator/GPIO route | preserve |
| IR | PWM remote-control node | preserve |
| GMAC | present in DTS but `status = "disabled"` | Android Ethernet product feature disabled by default |
| Camera | MIPI CSI connectors exist; example sensor nodes disabled in DTS | camera product/HAL disabled by default; opt-in after sensor/mezzanine is known |
| Onboard tablet sensors | no matching base-board gravity/light sensor set | disable generic RK3399 gravity/light sensor advertisements |

The generated Android DTS intentionally differs from the pinned upstream ROCK960 DTS in one Wi-Fi identity field: `wifi_chip_type="ap6354"` is rewritten to `wifi_chip_type="ap6356s"`. The controller does not alter the upstream file in place and does not change the board's SDIO or GPIO wiring.
