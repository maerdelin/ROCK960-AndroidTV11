# Storage, USB-C and PCIe

## eMMC

ROCK960 uses the RK3399 SDHCI controller with 8-bit HS400, 1.8 V signaling and enhanced strobe. The ATV product's boot device remains `fe330000.sdhci`.

## microSD

The ROCK960 board DTS retains the SDMMC card-detect/pinctrl and high-speed settings.

## USB-C

The board DTS has a FUSB302/FUSB30x Type-C controller at I2C address 0x22, associated with U2PHY0 and USB3 DRD0 for OTG. This is not copied from Tinker Board 2.

### DisplayPort over USB-C

ROCK960 hardware supports DisplayPort 1.2 over Type-C, but the exact A/B DTS in this ASUS kernel tag does not explicitly enable a board `&cdn_dp` route. The first image therefore validates Type-C as USB data/OTG only and uses HDMI as the TV display. DP is intentionally deferred rather than enabled with a generic RK3399 assumption.

## USB host

The ROCK960 DTS enables EHCI/OHCI host blocks and the second DWC3 controller as host.

## PCIe

The board DTS retains ROCK960 PCIe regulator/GPIO control. Android userspace does not need a Tinker-specific PCIe overlay for basic NVMe enumeration; kernel driver/device behavior is verified at first boot.
