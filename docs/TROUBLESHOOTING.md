# Troubleshooting DarkniusX

## 1. During sync / setup

### `repo: command not found`

Arch/CachyOS:

```bash
sudo pacman -S repo
```

Or install the launcher:

```bash
mkdir -p ~/.local/bin
curl -LSs https://storage.googleapis.com/git-repo-downloads/repo -o ~/.local/bin/repo
chmod a+x ~/.local/bin/repo
export PATH="$HOME/.local/bin:$PATH"
```

### `repo sync` fails / connection drops

Retry with fewer jobs:

```bash
cd "$HOME/darkniusx/aosp"
repo sync -c -j4 --no-tags --no-clone-bundle --force-sync
```

If it still fails, check the disk:

```bash
df -h "$HOME"
```

### `error: Your local changes to the following files would be overwritten`

This usually happens because the KernelSU integration lives in `common/`.
`setup.sh` uses `--force-sync`; if the error persists:

```bash
cd "$HOME/darkniusx/aosp/common"
git checkout -f
git reset --hard
```

Then run `bash scripts/setup.sh --no-sync`.

### `repo sync` is slow / stuck on prebuilts

The prebuilt clang is fairly large. Make sure no proxy blocks
`android.googlesource.com` and `storage.googleapis.com`. Try:

```bash
repo sync -c -j2 --no-tags --no-clone-bundle --force-sync prebuilts-master/clang/host/linux-x86
```

## 2. During the build

### `clang: error: unknown argument` / unknown compiler feature

Check whether the fragment is actually being used:

```bash
grep -n "CLANG_PREBUILT_BIN" "$HOME/darkniusx/aosp/.darkniusx/build/fragment.sh"
"$HOME/darkniusx/aosp/prebuilts-master/clang/host/linux-x86/clang-r416183b/bin/clang" --version
```

Make sure `CLANG_PREBUILT_BIN` points to `clang-r416183b`, not
`clang-r563880b`.

If the source really requires a newer compiler, download `clang-r563880b`
separately and change the path in `build/fragment.sh`. Do not edit
`build.config.common` directly; those changes are lost during the overlay.

### `check_defconfig` fails / `savedefconfig does not match`

The fragment was not sourced. Check:

```bash
grep -n "BUILD_CONFIG_FRAGMENTS" "$HOME/darkniusx/logs/build-"*.log | head
```

Make sure this file exists:

```text
$HOME/darkniusx/aosp/.darkniusx/build/fragment.sh
```

and that `POST_DEFCONFIG_CMDS` in that file overrides `check_defconfig`.

### `ERROR: CONFIG_KSU is not enabled`

The KernelSU setup failed or the KSU fragment was not applied. Check:

```bash
cd "$HOME/darkniusx/aosp/common"
ls -l drivers/kernelsu
grep -n kernelsu drivers/Makefile
grep -n 'drivers/kernelsu/Kconfig' drivers/Kconfig
git -C KernelSU-Next describe --tags --exact-match
```

There must be a symlink, Makefile/Kconfig entries, and the `v3.4.2` tag. If
not:

```bash
cd "$HOME/darkniusx/aosp/common"
curl -LSs https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/v3.4.2/kernel/setup.sh | bash -s v3.4.2
```

### `Killed` / build OOM

Symptom: the `clang` or `ld.lld` process disappears and the log stops without
a clear error.

Solutions:

```bash
CPUSET=0-1 bash scripts/build.sh vanilla thin
```

or add swap:

```bash
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

Do not use `LTO=full` with 15 GiB RAM and 6+ jobs.

### `ld.lld: error: unable to find library -l...`

This usually means the hermetic toolchain / sysroot is incomplete. Make sure
the sync completed:

```bash
cd "$HOME/darkniusx/aosp"
repo sync -c -j4 --force-sync build prebuilts/build-tools prebuilts/kernel-build-tools
```

Also check that `clang-r416183b/bin/ld.lld` exists.

### `Image.lz4` is missing after the build

The build stopped before the copy stage. Find the first error:

```bash
grep -n -iE "error:|fatal:|failed|Killed" "$HOME/darkniusx/logs/build-vanilla-"*.log | head -30
```

### `compare_to_symbol_list` / KMI mismatch

This means a config change modified an exported symbol. Revert the fragment to
the baseline, then add changes one at a time. Do not disable GKI options that
affect the ABI (see `config/base.config`).

### `modules list out of date`

`CONFIG_KSU=y` should be built-in, not a module. If KSU was built as `m`,
change it to `y`. Check:

```bash
grep '^CONFIG_KSU=' "$HOME/darkniusx/out/ksu/common/.config"
```

### `taskset: failed to set ... affinity`

The container/host restricts CPU affinity. Check the available CPUs:

```bash
taskset -pc $$
nproc
```

Use a valid `CPUSET`, for example `CPUSET=0-1`.

## 3. During flashing

### `adb: no devices/emulators found`

```bash
adb kill-server
adb start-server
adb devices
```

Make sure USB debugging is enabled and the RSA key is authorized on the
device.

### Recovery rejects the zip (signature verification)

The AnyKernel3 zip is not signed with the factory OTA key. Use a custom
recovery (TWRP/OrangeFox) or flash a `boot.img` via fastboot. Do not disable
OTA verification permanently unless you understand the risks.

### Bootloop

1. Wait 15 minutes.
2. Enter recovery/fastboot.
3. Restore `boot-stock.img`.
4. Restore `vendor_boot`/`vendor_dlkm` if needed.
5. Do not flash the same zip again.

Common causes:

- KMI mismatch (`android13-11` vs `android12-9`).
- Zip for a different device.
- Incompatible boot image/header.
- `vendor_dlkm` was modified at the same time.

### WiFi / Bluetooth / touch not working

Check:

```bash
adb shell uname -r
adb shell dmesg | grep -iE 'version magic|module verification failed|failed to load'
adb shell cat /proc/modules | grep -iE 'wlan|bt|touch'
```

If `uname -r` is not `android12-9`, the kernel has the wrong KMI. Restore the
stock boot image.

If a module fails because of vermagic, check the flags:

```bash
adb shell dmesg | grep -i "should be"
```

With `CONFIG_MODVERSIONS`, the release string is ignored; only the flags after
the first space are compared. Make sure `CONFIG_SMP`, `CONFIG_PREEMPT`, and
`CONFIG_MODULE_UNLOAD`/`MODVERSIONS` were not changed.

### KernelSU Manager says "not installed"

- Make sure you are using **KernelSU-Next Manager**, not the official KernelSU
  app.
- The manager version must match kernel `v3.4.2`.
- Check `adb shell su -v`; if it is missing, the KSU kernel is not installed or
  the manager lacks permission.
- Check `dmesg | grep -i kernelsu`.

### `su` is not found

KernelSU does not provide a `su` binary in `/system`; the manager provides the
interface. Use the correct manager and grant root to the shell/terminal.

## 4. Logs to collect

When reporting a problem, include:

```bash
uname -r
getprop ro.product.device
getprop ro.board.platform
getprop ro.build.version.release
getprop ro.boot.slot_suffix
dmesg | tail -200
cat /proc/modules | head -50
```

For builds:

```text
$HOME/darkniusx/logs/build-<variant>-<timestamp>.log
$HOME/darkniusx/out/<variant>/common/.config
$HOME/darkniusx/artifacts/<variant>/BUILD_INFO.txt
```

## 5. Starting clean

If the build tree is too messy:

```bash
# Remove one variant's output
rm -rf "$HOME/darkniusx/out/vanilla"
rm -rf "$HOME/darkniusx/artifacts/vanilla"

# Re-apply the source overlay (without syncing)
bash scripts/setup.sh --no-sync

# Rebuild
bash scripts/build.sh vanilla thin
```

For a full re-sync (warning: large download):

```bash
rm -rf "$HOME/darkniusx/aosp"
bash scripts/setup.sh
```
