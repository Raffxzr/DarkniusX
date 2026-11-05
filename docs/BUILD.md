# DarkniusX Build Guide

This guide explains how to build the **DarkniusX** kernel for Android 12 /
GKI Linux 5.10 from scratch on CachyOS (Arch-based), including the **Vanilla**
and **KernelSU Next** variants.

> **Status:** host builds for both variants (Vanilla and KernelSU Next) have
> succeeded, including the KMI check. The kernel has not been tested on a
> physical device yet. Do not flash before reading the compatibility and
> backup sections.

---

## 0. Overview

You will produce:

| File | Contents |
|---|---|
| `Image` | uncompressed ARM64 kernel |
| `Image.lz4` | LZ4-compressed kernel (GKI format) |
| `System.map` | kernel symbols |
| `config` | final kernel configuration |
| `DarkniusX-<variant>-5.10.272-<date>.zip` | AnyKernel3 package for flashing to the `boot` partition |

Estimated requirements:

- Disk: **30–40 GiB** for source + prebuilts, **10–20 GiB per variant** of output.
- Sync time: 15–60 minutes depending on the connection.
- Build time: **30–60 minutes per variant** with 4 cores and ThinLTO.
- RAM: 15 GiB is enough for ThinLTO; Full LTO should have 32 GiB+.

---

## 1. Compatibility warning (read first)

This project is only for:

- GKI **android12-5.10** kernels, KMI generation **9**.
- Devices with a `boot` partition (GKI boot image).
- Vendor modules built for KMI generation 9.

Check on the device:

```bash
adb shell uname -r
adb shell getprop ro.product.device
adb shell getprop ro.board.platform
adb shell getprop ro.build.version.release
adb shell getprop ro.build.ab_update
```

Example of a **compatible** output:

```text
5.10.269-android12-9-g222b41edc3a2-ab16633388
```

The important part is `-android12-9-`. If the output looks like:

```text
5.10.xxx-android13-11-...
```

then the device uses KMI generation 11 (android13-5.10). **Do not flash** this
kernel; vendor modules will not match.

Check the partitions:

```bash
adb shell 'ls -l /dev/block/by-name | grep -E "boot|vendor_boot|vendor_dlkm|dtbo"'
```

If `vendor_boot` or `vendor_dlkm` is missing, verify the flashing layout before
continuing; the scheme may differ.

> Note: a different `uname -r` does **not** automatically break vendor modules.
> GKI uses `CONFIG_MODVERSIONS=y`; when loading a module, the kernel ignores the
> first token (the release name) and compares only the vermagic flags and
> symbol CRCs. So `5.10.272-DarkniusX` can still load modules built for
> `5.10.269-android12-9`. What **must not** change is the struct layout and the
> GKI symbol CRCs.

---

## 2. Prerequisites

- CachyOS/Arch Linux (host) with `sudo`.
- 8 CPU cores (4 cores still works, but is slower).
- 15 GiB RAM + swap.
- At least 80 GiB of free space on a Linux filesystem (ext4/btrfs).
- A USB cable + `adb`/`fastboot` for flashing.
- An unlocked bootloader and a way to restore `boot` (fastboot or custom
  recovery).

**Do not build on an NTFS filesystem.** The kernel source requires symlinks,
permissions, and case sensitivity. The default workspace `$HOME/darkniusx` is
on Btrfs.

Check:

```bash
findmnt -no FSTYPE --target "$HOME"
df -h "$HOME"
free -h
nproc
```

---

## 3. Set up the project

This project lives at:

```text
/mnt/sdb2/Documents/Project/Raff/DarkniusX
```

That folder only contains scripts/configs (text files), so it is safe on NTFS.
Only the build workspace (`$HOME/darkniusx`) is moved to Btrfs.

```bash
cd /mnt/sdb2/Documents/Project/Raff/DarkniusX
chmod +x scripts/*.sh 2>/dev/null || true
```

On NTFS `chmod` may have no effect; every script can still be run with
`bash scripts/...`.

---

## 4. Install host dependencies

```bash
bash scripts/install-deps.sh
```

The script uses `pacman` on Arch/CachyOS. Important packages:

```text
base-devel git repo make bc bison flex cpio rsync zip unzip lz4 dtc
python3 curl openssl libelf ncurses
```

If you prefer not to use the script:

```bash
sudo pacman -S --needed base-devel git repo make bc bison flex cpio rsync \
  zip unzip lz4 dtc python curl openssl libelf ncurses
```

Check:

```bash
repo --version
clang --version        # host clang is not used, but useful as a sanity check
```

> **Distrobox option:** if you do not want to add packages on the host, use an
> existing Ubuntu 22.04 container (`gki-builder`) and install
> `git repo make bc bison flex cpio libelf-dev libssl-dev libncurses-dev
> rsync zip unzip lz4 device-tree-compiler python3 curl`. The build must still
> run in `$HOME` (Btrfs), not in `/mnt/sdb2`.

---

## 5. Sync the AOSP source + overlay the fork

```bash
bash scripts/setup.sh
```

What the script does:

1. `repo init` the `kernel/manifest` manifest, branch `common-android12-5.10`,
   with `--depth=1`.
2. `repo sync -c -j8 --no-tags --no-clone-bundle --force-sync`.
3. Overlay `common/` with the fork:
   - remote `darkniusx` → `https://github.com/lifeats666ln/kernel_common-5.10.git`
   - fetch branch `android12-5.10`
   - check out commit `f04d8c2a2f78a836d81d7ab0c1ab675f4ddddc9f`
4. Copy the config fragments into `aosp/.darkniusx/`.

Result:

```text
$HOME/darkniusx/
├── aosp/
│   ├── build/
│   ├── common/          # <- fork 5.10.272
│   ├── prebuilts-master/clang/host/linux-x86/clang-r416183b/
│   └── ...
├── out/
│   ├── vanilla/
│   └── ksu/
└── artifacts/
```

Check the source version:

```bash
git -C "$HOME/darkniusx/aosp/common" log -1 --oneline
grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL) =' "$HOME/darkniusx/aosp/common/Makefile"
```

You should see commit `f04d8c2` and Linux `5.10.272`.

### Why is the compiler overridden?

The fork uses a newer ACK `build.config.common` and requests
`clang-r563880b`. The `common-android12-5.10` manifest only provides
`clang-r416183b` (the compiler actually used by this AOSP branch).

`build/fragment.sh` overrides:

```bash
CLANG_PREBUILT_BIN=prebuilts-master/clang/host/linux-x86/clang-r416183b/bin
```

Check the compiler:

```bash
"$HOME/darkniusx/aosp/prebuilts-master/clang/host/linux-x86/clang-r416183b/bin/clang" --version
```

If a build ever fails because of a missing compiler feature, consider
downloading `clang-r563880b` separately. For source 5.10.272 based on this AOSP
branch, `r416183b` should be sufficient.

---

## 6. Build the Vanilla variant

```bash
bash scripts/build.sh vanilla thin
```

Explanation:

- `thin` = ThinLTO, much more RAM-efficient than Full LTO.
- The default `CPUSET=0-3` → 4 build jobs. For 6 jobs:
  ```bash
  CPUSET=0-5 bash scripts/build.sh vanilla thin
  ```
- The script runs `mrproper` on every build. For a fast rebuild without
  deleting the output:
  ```bash
  SKIP_MRPROPER=1 bash scripts/build.sh vanilla thin
  ```

Internal flow:

```text
ensure_overlay
  -> prepare config fragment
  -> BUILD_CONFIG=common/build.config.gki.aarch64
  -> BUILD_CONFIG_FRAGMENTS=.darkniusx/build/fragment.sh
  -> make gki_defconfig
  -> POST_DEFCONFIG_CMDS: append config/base.config, olddefconfig
  -> LTO=thin
  -> make Image Image.lz4 modules
  -> package
```

Output:

```text
$HOME/darkniusx/out/vanilla/dist/Image
$HOME/darkniusx/out/vanilla/dist/Image.lz4
$HOME/darkniusx/out/vanilla/dist/System.map
$HOME/darkniusx/artifacts/vanilla/DarkniusX-vanilla-5.10.272-YYYYMMDD.zip
```

Build log:

```text
$HOME/darkniusx/logs/build-vanilla-YYYYMMDD-HHMMSS.log
```

### Full LTO (optional, for releases)

```bash
CPUSET=0-3 bash scripts/build.sh vanilla full
```

Full LTO requires much more RAM. With 15 GiB and 4 jobs, the OOM risk is high.
Use it only if you are confident, or add swap:

```bash
sudo swapon --show
```

For daily use, `thin` is sufficient; the runtime performance difference is
usually small.

---

## 7. Build the KernelSU Next variant

```bash
bash scripts/build.sh ksu thin
```

What it does:

1. Runs `KernelSU-Next/kernel/setup.sh v3.4.2` from `aosp/common`.
2. Setup creates the `drivers/kernelsu` symlink and adds entries to
   `drivers/Makefile` + `drivers/Kconfig`.
3. Effective config = `config/base.config` + `config/ksu.config`
   (`CONFIG_KSU=y`).
4. Builds as usual.

Verify in the log:

```text
-- KernelSU-Next version: ...
-- KernelSU-Next tag: v3.4.2
```

Important notes:

- KernelSU Next `v3.4.2` does **not** use `CONFIG_KSU_KPROBES_HOOK`. Older
  documentation mentions that symbol; adding it has no effect.
- `CONFIG_KPROBES=y` and `CONFIG_EXT4_FS=y` are already present in
  `gki_defconfig`.
- Use the matching **KernelSU-Next Manager** version (`v3.4.2`), not the
  official KernelSU app. The wrong manager reports "KernelSU not installed"
  even when the kernel is correct.

Output:

```text
$HOME/darkniusx/artifacts/ksu/DarkniusX-ksu-5.10.272-YYYYMMDD.zip
```

---

## 8. Verify the build output

### 8.1 Check files and sizes

```bash
ls -lh "$HOME/darkniusx/out/vanilla/dist/"
ls -lh "$HOME/darkniusx/artifacts/vanilla/"
```

Approximate sizes:

- `Image`: 30–45 MB
- `Image.lz4`: 10–16 MB
- zip: 15–25 MB

If `Image` is only a few MB, the build failed or `MAKE_GOALS` is wrong.

### 8.2 Check the final config

```bash
CONFIG="$HOME/darkniusx/out/vanilla/common/.config"
grep -E '^CONFIG_LOCALVERSION=|^CONFIG_KASAN=|^CONFIG_KASAN_HW_TAGS=|^CONFIG_PAGE_OWNER=|^CONFIG_DEBUG_LIST=|^CONFIG_UBSAN=|^CONFIG_KFENCE=|^CONFIG_SCHEDSTATS=|^CONFIG_SCHED_DEBUG=' "$CONFIG"
```

Expected:

```text
CONFIG_LOCALVERSION="-DarkniusX"
CONFIG_KASAN=y
CONFIG_KASAN_HW_TAGS=y
CONFIG_PAGE_OWNER=y
CONFIG_DEBUG_LIST=y
# CONFIG_UBSAN is not set
# CONFIG_KFENCE is not set
CONFIG_SCHEDSTATS=y
CONFIG_SCHED_DEBUG=y
```

`KASAN`/`KASAN_HW_TAGS`, `PAGE_OWNER`, `DEBUG_LIST`, `SCHEDSTATS`, and
`SCHED_DEBUG` intentionally stay `y`: their symbols are in the GKI KMI lists
and/or the options change struct layouts used by vendor modules. Only `UBSAN`
and `KFENCE` are disabled because they are pure debug instrumentation with no
KMI symbols.

For KSU:

```bash
grep -E '^CONFIG_KSU=|^CONFIG_KSU_DEBUG=' "$HOME/darkniusx/out/ksu/common/.config"
```

Expected:

```text
CONFIG_KSU=y
# CONFIG_KSU_DEBUG is not set
```

### 8.3 Check the release string

The kernel has not run yet, but `include/config/kernel.release` can be checked:

```bash
cat "$HOME/darkniusx/out/vanilla/common/include/config/kernel.release"
```

Expected:

```text
5.10.272-DarkniusX
```

### 8.4 Check the KMI

```bash
ls -lh "$HOME/darkniusx/out/vanilla/dist/abi.xml" \
       "$HOME/darkniusx/out/vanilla/dist/abi.prop" 2>/dev/null
```

The GKI build runs the KMI check. If the build completes, the symbol list and
ABI check have passed.

---

## 9. Universal packaging (KMI guard)

The build script automatically calls `scripts/package.sh`. To repackage without
rebuilding:

```bash
bash scripts/package.sh vanilla
bash scripts/package.sh ksu
```

### No codename check

The zip is intentionally **universal** for every device running GKI
`android12-5.10` (KMI generation 9), not for one specific codename.
`do.devicecheck=0`, so `ro.product.device` is not checked.

The guard lives in `anykernel.sh`:

1. The kernel must be in the `boot` partition (not `vendor_boot`).
2. The currently installed kernel must contain `-android12-9-` (stock) or
   `-DarkniusX` (a previous DarkniusX build). The second token lets updates and
   Vanilla ↔ KSU switches be flashed directly.
3. If either condition fails, installation is aborted before writing to the
   partition.

This means devices using `android13-11` or a kernel layout in `vendor_boot` are
rejected automatically. This is safer than a codename-based device check,
because the same codename can use different KMIs across firmware versions.

### Zip contents

```text
anykernel.sh
Image
META-INF/
tools/
```

`anykernel.sh` uses `BLOCK=boot`, `IS_SLOT_DEVICE=1`, and only replaces the
kernel in the `boot` partition. The ramdisk, `vendor_boot`, `vendor_dlkm`, and
`dtbo` are not touched. The GPU overclock flasher remains a separate project
and is **not** merged into this zip.

---

## 10. Backup and flashing

> This section is generic. Without device details (codename, slot, recovery),
> commands may differ. Collect the output from section 1 for exact
> instructions.

### 10.1 Back up partitions

Back up at least `boot`; backing up `boot`, `vendor_boot`, `vendor_dlkm`, and
`dtbo` is safer.

Check partition names:

```bash
adb shell 'ls -l /dev/block/by-name/ | grep -E "boot|vendor_boot|vendor_dlkm|dtbo"'
```

Back up (the device must be rooted / `adb root`):

```bash
adb shell su -c 'dd if=/dev/block/by-name/boot of=/sdcard/boot-stock.img'
adb shell su -c 'dd if=/dev/block/by-name/vendor_boot of=/sdcard/vendor_boot-stock.img'
adb shell su -c 'dd if=/dev/block/by-name/vendor_dlkm of=/sdcard/vendor_dlkm-stock.img'
adb pull /sdcard/boot-stock.img
adb pull /sdcard/vendor_boot-stock.img
adb pull /sdcard/vendor_dlkm-stock.img
```

On A/B devices, `by-name/boot` is usually a symlink to the active slot. Check:

```bash
adb shell getprop ro.boot.slot_suffix
adb shell 'readlink -f /dev/block/by-name/boot'
```

Keep the backup on a computer, not only on `/sdcard`.

### 10.2 Flash via custom recovery

The most common method for AnyKernel3 zips:

```bash
adb reboot recovery
# in recovery: Advanced -> ADB Sideload
adb sideload DarkniusX-vanilla-5.10.272-YYYYMMDD.zip
```

Or:

```bash
adb push DarkniusX-vanilla-5.10.272-YYYYMMDD.zip /sdcard/
# in recovery: Install -> select the zip
```

If the stock recovery rejects the zip (signature verification), use a custom
recovery (TWRP/OrangeFox) or flash a `boot.img` via fastboot. This zip is not
signed with the factory OTA key.

### 10.3 First boot

- The first boot can take 5–10 minutes (dex2oat / verification).
- The device may reboot once.
- If it bootloops for more than 15 minutes, restore the backup.

### 10.4 Verify after boot

```bash
adb shell uname -r
# 5.10.272-DarkniusX

adb shell cat /proc/modules | head
adb shell dmesg | grep -iE 'version magic|module verification failed|failed to load'
adb shell getprop ro.boot.verifiedbootstate
```

Check important functions:

- WiFi and Bluetooth turn on.
- The touchscreen is responsive.
- Camera, audio, and sensors work.
- No spontaneous reboots while idle.

For KSU:

```bash
adb shell su -v
# or open KernelSU-Next Manager
```

### 10.5 Rollback

If the fastboot bootloader is available:

```bash
adb reboot bootloader
fastboot flash boot boot-stock.img
fastboot reboot
```

A/B:

```bash
fastboot flash boot_a boot-stock.img
# or boot_b for the active slot
```

If fastboot is not available, restore via recovery:

```bash
adb shell su -c 'dd if=/sdcard/boot-stock.img of=/dev/block/by-name/boot'
```

---

## 11. Benchmark

Run under identical conditions (temperature, battery, background apps) and
compare:

1. Stock kernel
2. DarkniusX Vanilla
3. DarkniusX KSU

At minimum:

```bash
adb shell dumpsys thermalservice
adb shell cat /proc/loadavg
adb shell 'cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq'
```

Apps:

- Geekbench 6 (CPU)
- 3DMark Wild Life (GPU/thermal)
- AnTuTu (optional; scores often change)
- `fio`/AndroBench for storage (optional)

Run 3 times, take the median, and let the device cool between runs. Do not draw
conclusions from a single run.

Details: [`BENCHMARK.md`](BENCHMARK.md).

---

## 12. Source updates and reproducibility

### Update the fork

The fork is pinned to a specific commit in `scripts/env.sh`:

```bash
FORK_COMMIT="f04d8c2a2f78a836d81d7ab0c1ab675f4ddddc9f"
```

For a deliberate update:

```bash
git ls-remote https://github.com/lifeats666ln/kernel_common-5.10.git refs/heads/android12-5.10
```

Replace `FORK_COMMIT` with the new hash, then:

```bash
bash scripts/setup.sh --no-sync
```

The script refuses to overlay if the fork HEAD does not match the pin; this
prevents accidental updates.

### Update the AOSP manifest

```bash
bash scripts/setup.sh
```

`repo sync` follows the latest manifest branch. After updating, rebuild and
test.

### Save the locked revisions

```bash
bash scripts/freeze.sh
```

The output contains `manifest.xml` (all projects pinned to SHAs),
`versions.txt`, and the configs used. Keep this folder with the release.

---

## 13. Troubleshooting

See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) for the full list. Common issues:

| Symptom | Cause / solution |
|---|---|
| `repo: command not found` | `sudo pacman -S repo` or the `~/.local/bin/repo` launcher |
| `clang: error: unknown argument` | Make sure `CLANG_PREBUILT_BIN` points to `clang-r416183b`; check `build/fragment.sh` |
| `check_defconfig` fails | The fragment was not sourced; check `BUILD_CONFIG_FRAGMENTS` and the `.darkniusx/build/fragment.sh` path |
| `CONFIG_KSU` is not enabled | KernelSU setup failed; check the `common/drivers/kernelsu` symlink and `drivers/Kconfig` |
| Build OOM / `Killed` | Use `LTO=thin`, `CPUSET=0-1`, close apps, add swap |
| `Image.lz4` is missing | The build failed before the copy stage; find the first error in the log |
| Bootloop | Restore `boot-stock.img`; never flash a zip without a backup |
| WiFi/BT not working | Check that `uname -r` contains `android12-9`; check `dmesg` for module load failures |
| KSU Manager "not installed" | Use KernelSU-Next Manager v3.4.2, not the official manager |
| `verity`/`vbmeta` error | AnyKernel3 `PATCH_VBMETA_FLAG=auto`; if needed, flash `vbmeta` with disable-verity |

---

## 14. Pre-release checklist

- [ ] `uname -r` on the device is `5.10.272-DarkniusX`
- [ ] No `version magic` / `module verification failed` in `dmesg`
- [ ] WiFi, Bluetooth, touch, camera, audio, and sensors work
- [ ] No spontaneous reboots after 24 hours
- [ ] Stock vs Vanilla vs KSU benchmark results are recorded
- [ ] The `-android12-9-` KMI guard is active in the zip (not a device/codename check)
- [ ] The GPU overclock flasher remains separate from the kernel zip
- [ ] `boot`/`vendor_boot`/`vendor_dlkm` backups are stored
- [ ] `freeze.sh` has been run and the manifest is saved
- [ ] The zip is uploaded to GitHub Releases with `SHA256SUMS` and `BUILD_INFO.txt`

---

## 15. Notes on the performance configuration

The `lifeats666ln` fork already carries many tweaks in `gki_defconfig`:

- `CONFIG_PREEMPT=y`
- `CONFIG_TCP_CONG_BBR=y`, CUBIC disabled
- `CONFIG_DEFAULT_FQ_CODEL=y`
- `CONFIG_MQ_IOSCHED_ADIOS=y`, BFQ
- `CONFIG_PELT_UTIL_HALFLIFE_12=y`
- `CONFIG_RT_SOFTINT_OPTIMIZATION=y`
- `CONFIG_DAMON=y` (reclaim)
- `CONFIG_LTO_CLANG_FULL=y`, `CONFIG_CFI_CLANG=y`

Because of that, the DarkniusX fragment does **not** add new aggressive tweaks.
Its focus is removing unnecessary debug overhead without breaking the ABI. If
you want to experiment more aggressively, create a separate fragment and test
one change at a time; do not stack many options at once.
