# DarkniusX v1.0.0 (Linux 5.10.272)

> **Status: pre-release.** Host builds for both variants succeeded and passed
> the KMI check, but the kernel has **not been tested on a physical device**.
> Do not flash without a `boot` backup, and understand the bootloop risk.

DarkniusX is a GKI `android12-5.10` (KMI generation **9**) kernel that is
**universal**: it works on any device with KMI 9 and is not tied to a codename.
Two variants are available: **Vanilla** and **KernelSU Next**.

## Release contents

- Base: AOSP `common-android12-5.10` + `Raffxzr/DarkniusX-android12-5.10`
- Source commit: `9f80eedc577dc7232cd31b4bbc6b8e871f8a1c41`
- Linux: `5.10.272`
- `uname -r`: `5.10.272-DarkniusX`
- Toolchain: AOSP Clang `r416183b`
- LTO: ThinLTO (unless stated otherwise)
- KernelSU Next: `v3.4.2` (KSU variant, built-in `CONFIG_KSU=y`)

## Files

| File | Variant | Notes |
|---|---|---|
| `DarkniusX-vanilla-5.10.272-20261105.zip` | Vanilla | No root |
| `DarkniusX-ksu-5.10.272-20261105.zip` | KernelSU Next | Root via KernelSU-Next Manager |
| `SHA256SUMS` | Both | Checksums |
| `BUILD_INFO-vanilla.txt`, `BUILD_INFO-ksu.txt` | Both | Build details |
| `config-vanilla`, `config-ksu` | Both | Final kernel config |
| `manifest.xml` | — | Locked repo manifest |

## Compatibility

- **Universal** for every device running GKI `android12-5.10` (KMI 9); there is
  no device/codename check (`do.devicecheck=0`).
- Required: the stock `uname -r` contains `-android12-9-` (or the installed
  kernel is a previous DarkniusX build) **and** the kernel lives in the `boot`
  partition.
- **Not compatible** with `-android13-11-`, other KMIs, or devices whose kernel
  only exists in `vendor_boot`.
- The AnyKernel3 zip only replaces the kernel in the `boot` partition; it does
  not touch `vendor_boot`, `vendor_dlkm`, `dtbo`, or the GPU overclock module.
- The installer aborts automatically if the KMI guard is not satisfied.

Check the device before flashing:

```bash
adb shell uname -r
adb shell getprop ro.product.device
adb shell getprop ro.board.platform
```

## How to flash

See [`docs/FLASHING.md`](docs/FLASHING.md). In short:

1. Back up `boot` (and `vendor_boot`/`vendor_dlkm` if present).
2. Flash the zip from a custom recovery (TWRP/OrangeFox) or via sideload.
3. Boot and verify `uname -r`, WiFi/BT, touch, camera, and audio.

## Known issues

- Not yet tested on a physical device in the first release; see the status note
  in the README.
- `KASAN`/`KASAN_HW_TAGS`, `PAGE_OWNER`, `DEBUG_LIST`, `SCHEDSTATS`, and
  `SCHED_DEBUG` remain enabled for GKI KMI compatibility.
- Full LTO is not recommended on machines with less than 32 GiB RAM.

## Rollback

Restore `boot-stock.img` via fastboot or recovery:

```bash
fastboot flash boot boot-stock.img
fastboot reboot
```

## Checksum

See the `SHA256SUMS` file on this release page.
