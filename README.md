# DarkniusX

A GKI **Linux 5.10 (android12-5.10)** kernel focused on stability and daily
performance, available in two variants:

| Variant | Root | Notes |
|---|---|---|
| **Vanilla** | No | No root |
| **KernelSU Next** | Yes | Kernel + KernelSU Next `v3.4.2` (built-in, `CONFIG_KSU=y`) |

## Base

- AOSP common kernel: `common-android12-5.10` (KMI generation **9**)
- Source fork: [`lifeats666ln/kernel_common-5.10`](https://github.com/lifeats666ln/kernel_common-5.10), branch `android12-5.10`
- Pinned commit: `f04d8c2a2f78a836d81d7ab0c1ab675f4ddddc9f` (Linux **5.10.272**)
- Toolchain: AOSP Clang `r416183b` from the `common-android12-5.10` manifest
- Build system: legacy `build/build.sh`

## Quick start

Run every command from this project folder:

```bash
# 1. Check/install host dependencies (Arch/CachyOS)
bash scripts/install-deps.sh

# 2. Sync AOSP + overlay the fork (once; downloads several GB)
bash scripts/setup.sh

# 3. Build the Vanilla variant (ThinLTO, safe for 15 GiB RAM)
bash scripts/build.sh vanilla thin

# 4. Build the KernelSU Next variant
bash scripts/build.sh ksu thin

# or build both
bash scripts/build.sh all thin
```

Build outputs and AnyKernel3 zips are written to:

```text
$HOME/darkniusx/artifacts/vanilla/
$HOME/darkniusx/artifacts/ksu/
```

Full guide: [`docs/BUILD.md`](docs/BUILD.md)

## Device compatibility

The zip is **universal**: it is not tied to a single codename or vendor. It can
be used on any device that runs GKI `android12-5.10` (KMI generation 9) and
keeps its stock kernel in the `boot` partition. Check before flashing:

```bash
adb shell uname -r
# must contain: -android12-9-
```

If the output contains `android13-11` or another KMI, **do not flash**. Vendor
modules will not match.

`do.devicecheck=0`, so `ro.product.device` is not checked. The safety guard is
in `anykernel.sh`: the installer reads the kernel currently installed in
`boot` and aborts if it is neither `-android12-9-` (stock) nor a previous
DarkniusX build. This is intentionally stricter than a codename check, because
the same codename can use different KMIs across firmware versions.

The target device must have a `boot` partition (and usually `vendor_boot` and
`vendor_dlkm`). Always back up `boot`, `vendor_boot`, and `vendor_dlkm` before
trying a custom kernel. The GPU overclock flasher remains a separate project
and is not merged into this zip.

## Project layout

```text
DarkniusX/
├── build/fragment.sh       # BUILD_CONFIG_FRAGMENTS hook for the AOSP build
├── config/
│   ├── base.config         # shared config fragment (Vanilla)
│   └── ksu.config          # adds CONFIG_KSU=y
├── docs/
│   ├── BUILD.md            # full build guide
│   ├── FLASHING.md         # backup, flash, rollback
│   ├── BENCHMARK.md        # how to compare performance
│   └── TROUBLESHOOTING.md  # common errors
├── flasher/anykernel.sh    # AnyKernel3 template (kernel-only)
├── RELEASE_NOTES.md        # release notes template
└── scripts/
    ├── env.sh              # configuration and helper functions
    ├── install-deps.sh
    ├── setup.sh            # repo sync + fork overlay
    ├── build.sh            # build + package
    ├── package.sh          # artifacts + AnyKernel3 zip
    └── freeze.sh           # save the locked manifest/revisions
```

## Warnings

- The build must run on a Linux filesystem (ext4/btrfs).
- Custom kernels always carry a bootloop risk. Back up the `boot` partition
  before flashing.
- Current status: host builds for Vanilla and KernelSU Next succeeded
  (including the KMI check) and artifacts are available in `artifacts/`. The
  kernel has not been tested on a device yet; verify `uname -r`,
  vendor modules, WiFi/BT, and touch after flashing.

## License

The kernel source follows the GPL-2.0 license from Linux/AOSP. The scripts and
configs in this project are licensed under GPL-2.0-only.
