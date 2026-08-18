#!/usr/bin/env python3
"""Audit the pinned ASUS Android 11 RK3399 U-Boot for ROCK960 A/B boot-critical compatibility.

This intentionally does not import the old Android 7.1 96rocks U-Boot. Instead it verifies
that the newer ASUS/Rockchip Android 11 U-Boot keeps the critical RK3399/ROCK960 A/B boot
contract while retaining the newer Android/AVB/Fastboot implementation.
"""
import argparse
from pathlib import Path

DEFCONFIG_REQUIRED = [
    'CONFIG_ROCKCHIP_RK3399=y',
    'CONFIG_DEFAULT_DEVICE_TREE="rk3399-evb"',
    'CONFIG_ANDROID_BOOTLOADER=y',
    'CONFIG_ANDROID_AVB=y',
    'CONFIG_FASTBOOT_FLASH=y',
    'CONFIG_FASTBOOT_FLASH_MMC_DEV=0',
    'CONFIG_MMC_SDHCI=y',
    'CONFIG_MMC_SDHCI_ROCKCHIP=y',
    'CONFIG_PMIC_RK8XX=y',
    'CONFIG_BAUDRATE=1500000',
    'CONFIG_DEBUG_UART_BASE=0xFF1A0000',
    'CONFIG_USB_DWC3=y',
    'CONFIG_USB_GADGET_DOWNLOAD=y',
]

DTS_REQUIRED = [
    '#include "rk3399-sdram-lpddr3-4GB-1600.dtsi"',
    'rk808: pmic@1b',
    '&uart2',
    '&sdhci',
    'bus-width = <8>;',
    'mmc-hs400-1_8v;',
    'mmc-hs400-enhanced-strobe;',
    'non-removable;',
    'vcc5v0_host: vcc5v0-host-en',
    'gpio = <&gpio4 25 GPIO_ACTIVE_HIGH>;',
    '&usb_host0_ehci',
    '&usb_host0_ohci',
    '&usb_host1_ehci',
    '&usb_host1_ohci',
    '&usbdrd_dwc3_0',
]


def check_all(text: str, required: list[str], label: str) -> list[str]:
    return [item for item in required if item not in text]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--u-boot', required=True, dest='uboot')
    ap.add_argument('--report')
    args = ap.parse_args()

    root = Path(args.uboot).resolve()
    defconfig = root / 'configs/rk3399_defconfig'
    dts = root / 'arch/arm/dts/rk3399-evb.dts'
    if not defconfig.is_file():
        raise SystemExit(f'missing ASUS Android 11 RK3399 defconfig: {defconfig}')
    if not dts.is_file():
        raise SystemExit(f'missing ASUS Android 11 RK3399 EVB DTS: {dts}')

    cfg_text = defconfig.read_text()
    dts_text = dts.read_text()
    missing_cfg = check_all(cfg_text, DEFCONFIG_REQUIRED, 'defconfig')
    missing_dts = check_all(dts_text, DTS_REQUIRED, 'dts')
    if missing_cfg or missing_dts:
        lines = ['ROCK960 A/B U-Boot compatibility audit failed.']
        if missing_cfg:
            lines.append('Missing rk3399_defconfig contract:')
            lines.extend(f'  - {x}' for x in missing_cfg)
        if missing_dts:
            lines.append('Missing rk3399-evb.dts boot-critical contract:')
            lines.extend(f'  - {x}' for x in missing_dts)
        raise SystemExit('\n'.join(lines))

    report = (
        'board_family=ROCK960 Model A/B\n'
        'source_uboot=ASUS/TinkerBoard Android 11 2.0.8 RK3399\n'
        'uboot_defconfig=rk3399\n'
        'uboot_dts=rk3399-evb\n'
        'legacy_reference=96rocks rock960-ab-rk3399_defconfig\n'
        'debug_uart=UART2@1500000\n'
        'emmc=SDHCI 8-bit HS400 1.8V enhanced-strobe\n'
        'pmic=RK808\n'
        'fastboot_mmc_dev=0\n'
        'android_bootloader=yes\n'
        'android_avb=yes\n'
        'status=source-contract-pass; hardware-boot-not-yet-claimed\n'
    )
    if args.report:
        p = Path(args.report)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(report)
    print(report, end='')


if __name__ == '__main__':
    main()
