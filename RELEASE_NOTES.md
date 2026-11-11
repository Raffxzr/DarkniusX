# DarkniusX v1.1.0 (SUSFS & NTSYNC Edition)

> **Status: Pre-release.** Built with full SUSFS anti-detection, NTSYNC gaming acceleration, and KernelSU-Next.
> Always keep a stock `boot` backup before flashing any custom kernel.

DarkniusX is a high-performance, stealth-oriented GKI `android12-5.10` (KMI generation **9**) kernel that is **universal**: it works on any device with KMI 9 and is not tied to any device codename.

## What's New in v1.1.0

- **SUSFS v1.5.x Integration (Anti-Detection & Root Concealment)**:
  - Deep VFS and SELinux hooks built natively into the kernel.
  - Stealth root concealment bypassing root checkers, banking apps, and integrity checks.
  - Features enabled:
    - Path hiding (`CONFIG_KSU_SUSFS_SUS_PATH=y`)
    - Mount hiding & fake mnt_id allocation (`CONFIG_KSU_SUSFS_SUS_MOUNT=y`)
    - Inode/kstat spoofing (`CONFIG_KSU_SUSFS_SUS_KSTAT=y`)
    - Uname spoofing (`CONFIG_KSU_SUSFS_SPOOF_UNAME=y`)
    - Bootconfig/cmdline spoofing (`CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y`)
    - Open redirect (`CONFIG_KSU_SUSFS_OPEN_REDIRECT=y`)
    - Maps hiding (`CONFIG_KSU_SUSFS_SUS_MAP=y`)
    - Priority UID filter (`CONFIG_KSU_SUSFS_PRIORITY_UID_FILTER=y`)
- **NTSYNC Driver Support**:
  - Direct kernel driver at `/dev/ntsync` for fast Windows NT synchronization primitives.
  - Massive latency reduction and FPS boost for Windows translation layers (Wine, Proton, Winlator, Mobox).
- **KernelSU-Next Integration (`dev-susfs`)**:
  - Integrated with KernelSU-Next direct hooks for zero kprobe overhead and maximum stealth.
  - Compatible with KernelSU-Next Manager v3.4.2+.

## Release Details

- **Kernel:** Linux `5.10.272`
- **GKI Version:** Android 12 GKI (`-android12-9-`)
- **Kernel Source:** [`Raffxzr/DarkniusX-android12-5.10`](https://github.com/Raffxzr/DarkniusX-android12-5.10) @ `ec838f9e1114fb90dfb4ddbcdfe3d2114bdf7860`
- **Compiler:** Android Clang `r416183b` (LLVM 12.0.7)
- **Linker & LTO:** LLD + ThinLTO
- **Localversion:** `-DarkniusX`

## Files

| File | Variant | Description |
|---|---|---|
| `DarkniusX-ksu-5.10.272-20261111.zip` | KernelSU Next + SUSFS | AnyKernel3 flashable zip with root & SUSFS |
| `BUILD_INFO.txt` | Build metadata | CI build information and compiler versions |
| `SHA256SUMS.txt` | Checksum | SHA256 checksums for package verification |

## How to Flash

1. Boot device into custom recovery (**TWRP** / **OrangeFox**) or use **KernelFlasher**.
2. **(Important)** Create a backup of your existing `boot` partition.
3. Flash `DarkniusX-ksu-5.10.272-20261111.zip`.
4. Reboot system.
5. Install **KernelSU-Next Manager** (v3.4.2) to manage root permissions.
6. (Optional) Install the **SUSFS module** and companion APK to configure stealth features.

## Rollback

To return to the original kernel, restore your backup or flash the stock boot image:
```bash
fastboot flash boot boot-stock.img
fastboot reboot
```
