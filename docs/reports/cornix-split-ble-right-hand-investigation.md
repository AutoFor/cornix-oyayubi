# Cornix Split BLE Right-Hand Investigation

Date: 2026-06-08

## Summary

Cornix LP split BLE firmware was brought up with RMK 0.8.2 and custom Cornix configuration. The left half works as the USB HID central. The right half matrix can be read when flashed as a standalone central diagnostic, but the right half does not produce key events through split BLE when flashed as a peripheral.

The current failure is narrowed to BLE discovery:

- Left central starts and sends USB HID reports.
- Left central starts BLE scan.
- Left central receives general BLE advertisements.
- Left central does not see the right peripheral split advertisement.
- A minimal right-hand beacon firmware also has not been seen by the left central diagnostic.

## Hardware Identification

- Left half bootloader serial: `DBFC1ECF335A7FAC`
- Right half bootloader serial: `D3DD1D6E72A04658`
- Bootloader model: `cornix`
- Bootloader type: `Adafruit nRF UF2`
- Firmware layout uses `adafruit_bl` and `FLASH ORIGIN = 0x00001000`.

## Firmware Setup

Added an RMK firmware scaffold to this repository:

- `Cargo.toml`
- `Makefile.toml`
- `keyboard.toml`
- `keyboard-layout.json`
- `vial.json`
- `memory.x`
- `src/central.rs`
- `src/peripheral.rs`
- `src/right_beacon.rs`
- vendored RMK crates under `vendor/`

The current code includes diagnostic-only changes and is not yet production clean.

## Confirmed Working

### Left Central

The left half works as USB HID. It can type diagnostic markers and normal left-hand keys.

### Right Matrix

The right half was flashed with a standalone central matrix diagnostic using the right-hand matrix pins.

Observed physical right-hand key output:

```text
TREWQ
GFDSA
BVCXZ
```

This confirms the right-hand matrix wiring and configured row/column pins are readable.

## Tests and Attempts

### Normal Split Firmware

Flashed:

- Left `F:` -> `central.uf2`
- Right `E:` -> `peripheral.uf2`

Result:

- Left keys work.
- Right keys do not work.

### Clear Storage

Built and flashed temporary `clear_storage = true` firmware for both sides, then restored normal firmware.

Result:

- Left still works.
- Right still does not work.

### PHY Simplification

Changed `keyboard.toml` to `use_2m_phy = false`.

Also temporarily patched RMK `update_ble_phy` to skip forcing 2M PHY and stay on 1M PHY.

Result:

- No improvement.

### Reversed UF2 Assignment

Flashed right as central and left as peripheral.

Result:

- Both sides appeared nonfunctional for the intended layout.
- This did not indicate a simple left/right UF2 inversion.

### Central Diagnostic Markers

Added HID diagnostic markers to the central scan path.

Observed markers:

- `t`: central app and HID event path alive
- `Tab`: peripheral manager reached "no right address; request scan"
- `a`: scan task reached
- `r`: BLE scan started
- `d`: at least one BLE advertisement received

Markers not observed:

- `f`: split UUID seen
- `g`: split manufacturer data seen
- `q`: right peripheral recognized
- `w`: BLE connected
- `e`: split GATT setup complete

Typical observed output:

```text
<TAB>	ardt
```

Interpretation:

The central can scan and receive BLE advertisements, but the expected right-peripheral advertisement is not being matched.

### Peripheral Advertising Changes

Tried these changes on the split peripheral path:

- Forced undirected advertising.
- Ignored saved central address.
- Used only the actual encoded advertising length instead of passing the full 31-byte buffer.
- Simplified advertising to manufacturer data only.
- Relaxed central-side matching to manufacturer data only.

Result:

- Left central still did not observe right-specific markers.

### Minimal Right Beacon

Added `src/right_beacon.rs`, a minimal right-hand firmware that removes RMK split, matrix, storage, and key handling. It only starts BLE and advertises a small payload.

Variants tried:

- Manufacturer data beacon
- Manufacturer data plus local name `CRNX-R`

Left central diagnostic was updated to detect:

- `h`: local name `CRNX-R`
- `g`: manufacturer data
- `q`: right candidate recognized

Result:

- Still observed only scan/generic advertisement markers such as `<TAB> ardt`.
- No `h`, `g`, or `q`.

## Current Conclusion

The right-side matrix is readable, and the left central can scan BLE advertisements. The failure is currently between right-side BLE advertising and left-side discovery.

The strongest current hypothesis is that the right-side application either:

- does not reach the BLE advertising loop,
- advertises in a mode/channel/form that the current central scanner does not receive,
- fails during BLE stack or radio startup after bootloader handoff,
- or has a right-side BLE/radio hardware or board-level issue.

The issue is no longer primarily a keymap or matrix issue.

## Known Caveats

The working tree currently contains diagnostic-only patches:

- HID marker injection in RMK split central scan code
- forced scan behavior
- relaxed advertisement matching
- temporary 1M PHY behavior
- minimal `right_beacon` binary

These should be cleaned up or split into separate commits before production firmware is finalized.

## Next Recommended Steps

1. Capture right-side logs with `probe-rs` or another RTT/defmt path.
2. Confirm whether `right_beacon` reaches its advertise loop.
3. Use an external BLE scanner, such as a phone running nRF Connect, to check whether `CRNX-R` is visible.
4. If `CRNX-R` is visible externally but not to the left central, investigate central scan filtering/event handling.
5. If `CRNX-R` is not visible externally, focus on right-side BLE startup, radio configuration, board hardware, or bootloader handoff.
