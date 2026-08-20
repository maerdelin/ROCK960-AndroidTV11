# Changelog

## Unreleased — 2026-08-20 bring-up closure

- Wire `patches/rock960-kernel-build-fixups.patch` into the normal `make port` flow through
  an idempotent `scripts/apply-kernel-fixups.sh` helper.
- Preserve the verified `panel-simple.c` Tinker-MCU guards and ROCK960 Ethernet MAC fallback
  fix across clean ASUS 2.0.8 source checkouts.
- Keep the generated ROCK960 Android DTS fix that removes the stale ASUS `&vpu` node.
- Replace the default persistent-U-Boot/trust RKUpdate payload policy with the safer
  first-boot package used during real bring-up: outer `MiniLoaderAll.bin` is retained, while
  `uboot.img` and `trust.img` remain debug-only artifacts.
- Add `scripts/pack-safe-update.sh` with package-file policy checks and byte-for-byte packed
  `boot.img` verification.
- Add `scripts/repack-asus208-boot.sh` to reproduce and verify the ASUS-ramdisk + ROCK960
  kernel/DTB/resource boot image used during the first bring-up.
- Add `scripts/repack-asus208-current.sh` to reproduce the minimal official-ASUS-partitions
  + verified ROCK960 boot `update.img` workflow.
- Update artifact verification and controller tests so the kernel-fix and safe-packaging
  wiring cannot silently regress.
- Document the exact 2026-08-20 bring-up decisions in `docs/BRINGUP_2026-08-20.md`.

## v1.2.0-final

- Lock the target to original ROCK960 Model A/B and explicitly exclude ROCK960C.
- Keep AP6356S as the only Wi-Fi/BT module identity for this product.
- Keep BCM4356A2 STA/APSTA/P2P firmware aliases and `nvram_ap6356s.txt -> nvram.txt`.
- Add a source-contract U-Boot auditor for RK3399, UART2 1.5 Mbps, RK808, eMMC HS400,
  Fastboot MMC0, USB and Android/AVB support.
- Preserve the ASUS Android 11 U-Boot chain instead of importing the obsolete Android 7.1
  bootloader wholesale.
- Emit a persistent `uboot-rock960-audit.txt` report alongside the source audit.
- Add regression tests for U-Boot compatibility and the A/B-only board identity lock.

## v1.1.0

- Treat ROCK960 Model A/B Wi-Fi as AP6356S explicitly.
- Generate `wifi_chip_type = "ap6356s"` while leaving the pinned upstream DTS untouched.
- Install `nvram_ap6356s.txt` as `/vendor/etc/firmware/nvram.txt`.
- Install BCM4356A2 STA/APSTA/P2P firmware as generic bcmdhd aliases.
- Audit the kernel's fixed `fw_bcmdhd.bin` / `nvram.txt` loader paths.
- Compare installed Wi-Fi payloads byte-for-byte and by SHA-256 after Android build.
- Emit `WIFI-SHA256SUMS.txt` alongside final build artifacts.

## v1.0.0-final

- First controller release recommended for a real full ROCK960 Android TV 11 build on the pinned ASUS/Tinker Board 2 Android 11 2.0.8 BSP.
