# DarkniusX

<p align="center">
  <img src="https://img.shields.io/badge/Kernel-Linux%205.10.272-blue?style=for-the-badge&logo=linux" alt="Linux Version">
  <img src="https://img.shields.io/badge/GKI-Android%2012%20(KMI%209)-green?style=for-the-badge&logo=android" alt="GKI KMI 9">
  <img src="https://img.shields.io/badge/KernelSU%20Next-v3.4.2-orange?style=for-the-badge" alt="KernelSU Next">
  <img src="https://img.shields.io/badge/SUSFS-v1.5.x-purple?style=for-the-badge" alt="SUSFS">
  <img src="https://img.shields.io/badge/NTSYNC-Enabled-brightgreen?style=for-the-badge" alt="NTSYNC">
  <a href="https://github.com/Raffxzr/DarkniusX/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/Raffxzr/DarkniusX/build.yml?branch=main&label=CI%20Build&style=for-the-badge" alt="CI Build"></a>
  <img src="https://img.shields.io/badge/License-GPL--2.0-red?style=for-the-badge" alt="License">
</p>

A universal **Linux 5.10 (android12-5.10 / KMI generation 9)** Generic Kernel Image (GKI) focused on stability, daily performance, stealth root hiding, and low-latency gaming synchronization.

---

## 📌 Repositories in the DarkniusX Ecosystem

Following modern modular Android kernel projects (ATM SuiKernel), the project is split into focused repositories:

| Repository | Description |
|---|---|
| **[DarkniusX](https://github.com/Raffxzr/DarkniusX)** *(This repo)* | **Release Hub & Build Toolkit** — Flashable AnyKernel3 releases, documentation, issue tracking, and build harness. |
| **[DarkniusX-android12-5.10](https://github.com/Raffxzr/DarkniusX-android12-5.10)** | **Official Kernel Source Tree** — Full upstream Android Common Kernel source code (Linux 5.10.272) integrated with **SUSFS** and **NTSYNC**. |

---

## ⚡ Variants & Features

DarkniusX is available in two distinct flavors:

| Variant | Root Solution | Built-in Features | Best For |
|---|---|---|---|
| **Vanilla** | None | Pure GKI performance + **NTSYNC (`/dev/ntsync`)** | Daily drivers, stock feel, PC emulation gaming |
| **KernelSU Next** | KernelSU Next `v3.4.2` | Native root + **SUSFS v1.5.x (Anti-detection)** + **NTSYNC** | Power users requiring undetectable root (banks/games) |

### 🛡️ SUSFS (Superuser Root Hiding File System)
Integrated directly into the VFS subsystem (`fs/susfs.c`) with `CONFIG_KSU_SUSFS=y`:
* **Undetected Root:** Hides `/data/adb`, mount overlays, loop devices, and KSU-specific paths.
* **Integrity Bypass:** Spoofs `uname -r`, cmdline, and bootconfig for sensitive apps (banking, AlfaGift, Play Integrity).
* **Stealth Symbols:** Strips KSU/SUSFS trace symbols to prevent scanner hooks.

### 🎮 NTSYNC Driver
Integrated character device driver (`/dev/ntsync`) with `CONFIG_NTSYNC=y`:
* **Emulation Speedup:** Native Linux kernel-level Windows NT synchronization primitives (mutexes, semaphores, events).
* **Windows Gaming on Android:** Massively reduces CPU overhead in Wine, Mobox, Winlator, and Box64 for higher FPS and lower frametime jitter.

---

## 📥 Downloads

Ready-to-flash AnyKernel3 zip files are hosted on GitHub Releases:

👉 **[Go to Latest Releases](https://github.com/Raffxzr/DarkniusX/releases)**

| Package | Description |
|---|---|
| `DarkniusX-vanilla-5.10.272-<date>.zip` | Flashes the Vanilla (non-root) kernel |
| `DarkniusX-ksu-5.10.272-<date>.zip` | Flashes the KernelSU Next variant |
| `SHA256SUMS` | SHA256 checksums for integrity verification |

---

## 📱 Device Compatibility

DarkniusX is **Universal**: it does not lock to a specific brand or device codename (`do.devicecheck=0`). Any device that fulfills the following criteria is compatible:

1. **Kernel Type:** Stock kernel runs GKI **android12-5.10** with **KMI generation 9**.
2. **Boot Scheme:** Device stores its kernel in the standard `boot` partition (not solely in `vendor_boot`).

### How to verify your device before flashing:

Connect your phone via USB with USB Debugging enabled, then run:

```bash
adb shell uname -r
```

* **COMPATIBLE:** Output contains `-android12-9-` (for example: `5.10.209-android12-9-g...`).
* **INCOMPATIBLE:** Output contains `android13-11` or any other KMI generation. **DO NOT FLASH** if KMI doesn't match, or vendor modules will fail to load!

> **Safety Guard:** The AnyKernel3 installer checks the running kernel's vermagic and aborts automatically if the partition doesn't match `-android12-9-` or an existing DarkniusX build.

---

## 🚀 How to Flash

> [!WARNING]
> Always create a backup of your stock `boot` partition before flashing any custom kernel!
> Custom kernels always carry a bootloop risk. Back up `boot`, `vendor_boot`, and `vendor_dlkm` before trying a custom kernel.

### Method 1: Custom Recovery (TWRP / OrangeFox)
1. Download the preferred zip file (`Vanilla` or `KernelSU Next`) from [Releases](https://github.com/Raffxzr/DarkniusX/releases).
2. Boot into Recovery mode.
3. **Backup** the `Boot` partition (and `Vendor Boot`/`Vendor DLKM` if present).
4. Tap **Install**, select `DarkniusX-*.zip`, and swipe to flash.
5. Reboot System.

### Method 2: Recovery Sideload
```bash
adb reboot recovery
adb sideload DarkniusX-ksu-5.10.272-*.zip
```

### Rollback (If needed)
If you encounter any boot issues, restore your stock boot image via fastboot:
```bash
fastboot flash boot boot-stock.img
fastboot reboot
```

---

## 🛠️ Building from Source

If you want to compile DarkniusX locally:

```bash
# 1. Install host dependencies (Arch/CachyOS)
bash scripts/install-deps.sh

# 2. Sync AOSP build toolchain + DarkniusX source tree
bash scripts/setup.sh

# 3. Build Vanilla variant
bash scripts/build.sh vanilla thin

# 4. Build KernelSU Next variant
bash scripts/build.sh ksu thin
```

Detailed guide, troubleshooting, and benchmarks:
* 📖 [Build Documentation](docs/BUILD.md)
* 📖 [Flashing & Partition Layout Guide](docs/FLASHING.md)
* 📖 [Troubleshooting & FAQs](docs/TROUBLESHOOTING.md)
* 📖 [Benchmarking Notes](docs/BENCHMARK.md)

---

## 📄 License & Credits

* **Linux Kernel Source:** Licensed under **GPL-2.0**. Full source available at [Raffxzr/DarkniusX-android12-5.10](https://github.com/Raffxzr/DarkniusX-android12-5.10).
* **Build Toolkit & Scripts:** Licensed under **GPL-2.0-only**.
* **Special Thanks:**
  * The Linux Kernel and Android Open Source Project (AOSP) contributors.
  * [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) team for the modern kernel root solution.
  * osm0sis for the legendary AnyKernel3 flasher.
  * Inspiration from the SuiKernel project structure.
