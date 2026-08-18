# Build flow

`one-shot.sh` is intentionally staged so expensive work does not start before cheap failures are found.

1. `doctor.sh`: disk, RAM+swap, filesystem, Docker availability.
2. `network-preflight.sh`: exact release refs.
3. `sync.sh`: exact ASUS manifest and release tag set.
4. `apply-port.sh`: clone `rk3399_atv` -> `rock960_atv`; generate DTS.
5. `audit-source.sh`: hardware/source contracts.
6. `preflight-build.sh`: U-Boot, kernel/DTB and `m nothing`.
7. `build.sh`: rebuild U-Boot/kernel and full Android target.
8. `pack.sh`: collect generic RK3399 images and call `mkupdate_rk3399.sh`.
9. `verify-artifacts.sh`: required component and SHA-256 checks.

The controller never invokes Tinker Board's `sdboot.sh`, and it does not call the ASUS root `build.sh -u` because that script derives `mkupdate_$TARGET_PRODUCT.sh`, which does not exist for the new `rock960_atv` product.
