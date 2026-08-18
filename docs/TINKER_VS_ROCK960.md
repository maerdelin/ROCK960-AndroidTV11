# Tinker Board 2 vs ROCK960

Both boards use RK3399/Mali-T860, which is why the ASUS Android 11 BSP is useful for framework, media, graphics and Rockchip HALs. They are not electrically interchangeable.

This port does **not** use the Tinker Board 2 kernel device tree for ROCK960. It takes the generic RK3399 ATV Android product from the ASUS source tree, then selects the ROCK960 A/B kernel DTS that exists in the same kernel tag.

The important differences handled by that ROCK960 DTS include power rails, eMMC/SD wiring, SDIO Wi-Fi, Bluetooth UART/GPIOs, FUSB302 USB-C/OTG, USB host ports, PCIe power/control, HDMI/audio routing and board-specific suspend/thermal settings.
