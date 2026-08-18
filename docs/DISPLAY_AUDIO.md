# Display and audio

`rk3399-rock960-ab.dts` includes `rk3399-linux.dtsi`. In that Linux include, the display subsystem and HDMI route are disabled. Rockchip's Android RK3399 DTS enables the VOPs/MMUs, DDC timing and Android display state.

Instead of including the entire generic `rk3399-android.dtsi` (which would duplicate board nodes/labels), the generated ROCK960 Android DTS adds only:

- `firmware_android` node required by the RK3399 ATV DTBO template;
- VOP big/little + MMU enablement;
- HDMI DDC timing;
- display subsystem enablement;
- `route_hdmi` connected to `vopb_out_hdmi`;
- I2S2 `rockchip,bclk-fs = <128>`;
- hardware RNG enablement.

ROCK960's own DTS already defines an HDMI simple-audio-card with I2S2 and an SPDIF sound card; those are preserved.

The first bring-up intentionally targets HDMI. USB-C DisplayPort and MIPI-DSI are not automatically enabled because the exact ROCK960 A/B board DTS does not provide a complete explicit display route for them; adding a generic RK3399 route before HDMI is validated would reduce, not improve, first-boot reliability.
