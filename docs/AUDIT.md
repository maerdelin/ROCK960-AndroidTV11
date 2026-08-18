# Repository audit summary

v1.2.0-final controller checks:

- pinned ASUS 2.0.8 manifest and Android 11 r46 supplement;
- AOSP ATV source present in manifest;
- RK3399 ATV product is the generated product template;
- ROCK960 A/B DTS exists in the exact same kernel release;
- kernel config keeps RK3399 ATV `android-10.config` and verifies Rockchip common appends `android-11.config`;
- Mali-T860 target is retained;
- eMMC HS400, microSD, AP6356S SDIO wiring, BT UART0, FUSB302 USB-C, USB host, PCIe and HDMI board definitions are audited by source patterns;
- generated Android DTS rewrites only the pinned upstream Wi-Fi module label from `ap6354` to `ap6356s` while leaving board wiring intact;
- BCM4356A2 STA/APSTA/P2P firmware aliases and `nvram_ap6356s.txt -> nvram.txt` are required by source audit;
- the full Android build compares all four installed Wi-Fi aliases byte-for-byte and by SHA-256 and emits `WIFI-SHA256SUMS.txt`;
- Linux-root bootargs are stripped from the copied ROCK960 base include before Android boot;
- Android display glue is minimal and does not include generic `rk3399-android.dtsi` wholesale;
- generic RK3399 packer is used rather than Tinker-specific SD image scripts;
- generic tablet sensor/factory-test flags are neutralized for the base ROCK960 TV product;
- resolved build variables are checked again after `lunch` so AVB/kernel-fragment/ATV policy cannot silently drift;
- controller regression/contract tests cover product conversion, AP6356S DTS generation, firmware mapping, release pinning, AVB bring-up default and packaging contracts.

What this audit cannot replace: a several-hundred-GB `repo sync`, a full Android build and a ROCK960 hardware boot in the current tool environment. Those are deliberately the first real validation steps on the user's build machine.

- U-Boot source-contract auditor checks UART2 1.5 Mbps, RK808, eMMC HS400, MMC0 Fastboot, USB and Android/AVB capabilities against the pinned ASUS Android 11 RK3399 U-Boot.
