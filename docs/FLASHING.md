# Flashing

This repository intentionally does not auto-flash a board.

Before writing eMMC:

- confirm ROCK960 Model A/B;
- confirm Maskrom/loader mode recovery works from your host;
- back up important eMMC data;
- verify the generated SHA256SUMS;
- preferably have UART connected.

The artifact is a Rockchip `update.img` produced by the BSP's generic RK3399 packer. Use the ROCK960/96Boards recovery procedure and Rockchip tooling appropriate for your host. Keep the first flash supervised; do not automate it from CI.
