# Flashing and Rollback

This guide is generic for GKI `android12-5.10` devices. Partition commands can
differ depending on the codename and A/B layout. **Always verify partition
names on the device before running `dd`.**

## 1. Before you start

Make sure you have:

- An unlocked bootloader (or a custom recovery installed).
- `adb` and `fastboot` on your computer.
- Backups of `boot`, `vendor_boot`, `vendor_dlkm`, and `dtbo` (if present).
- The DarkniusX kernel zip.
- The stock kernel / a backup boot image for rollback.

Check the connection:

```bash
adb devices
adb shell getprop ro.product.device
adb shell getprop ro.boot.slot_suffix
adb shell uname -r
```

`uname -r` must contain `-android12-9-`.

## 2. Check partitions

```bash
adb shell 'ls -l /dev/block/by-name/ | grep -E "boot|vendor_boot|vendor_dlkm|dtbo"'
```

Example A/B device:

```text
boot_a -> /dev/block/sde12
boot_b -> /dev/block/sde13
vendor_boot_a -> /dev/block/sde14
vendor_boot_b -> /dev/block/sde15
vendor_dlkm_a -> /dev/block/sde16
vendor_dlkm_b -> /dev/block/sde17
```

`/dev/block/by-name/boot` is usually a symlink to the active slot. Do not
guess; check with `readlink -f`.

## 3. Backup

### 3.1 With root (easiest)

```bash
adb shell su -c 'dd if=/dev/block/by-name/boot of=/sdcard/boot-stock.img'
adb shell su -c 'dd if=/dev/block/by-name/vendor_boot of=/sdcard/vendor_boot-stock.img'
adb shell su -c 'dd if=/dev/block/by-name/vendor_dlkm of=/sdcard/vendor_dlkm-stock.img'
adb pull /sdcard/boot-stock.img
adb pull /sdcard/vendor_boot-stock.img
adb pull /sdcard/vendor_dlkm-stock.img
```

If you do not have root yet, use a custom recovery (TWRP/OrangeFox) → Backup →
select `Boot`, `Vendor Boot`, and `Vendor DLKM`.

### 3.2 Verify the backup

```bash
ls -lh boot-stock.img vendor_boot-stock.img vendor_dlkm-stock.img
file boot-stock.img
```

A `boot-stock.img` is usually 32–128 MB. Keep a copy on another computer or in
the cloud as well.

## 4. Flash the kernel

### 4.1 Custom recovery (recommended for AnyKernel3 zips)

```bash
adb reboot recovery
```

In recovery:

- TWRP/OrangeFox: **Install** → select the zip.
- Or **Advanced → ADB Sideload**, then:

```bash
adb sideload DarkniusX-vanilla-5.10.272-YYYYMMDD.zip
```

Do not wipe data. The zip only replaces the kernel in `boot`. It also includes
a guard: if the kernel currently in `boot` is not `-android12-9-` (or a
previous DarkniusX build), flashing is aborted automatically.

### 4.2 Fastboot (if you have a boot.img)

The AnyKernel3 zip is not a `boot.img`. To flash via fastboot, extract `Image`
from the zip and build a boot image with the appropriate tool, or use
`fastboot boot` on an already-built boot image. This path is riskier because
you must preserve the stock header and ramdisk.

For devices with `init_boot` (Android 13+), the kernel still lives in `boot`;
do not flash `init_boot`.

## 5. First boot

- 5–10 minutes is normal.
- The screen may stay black or the logo may sit still for several minutes.
- Do not panic and force-reboot before 15 minutes.
- If it keeps rebooting (bootloop) for more than 15 minutes, restore the backup.

## 6. Verify after boot

```bash
adb shell uname -r
adb shell cat /proc/modules | wc -l
adb shell dmesg | grep -iE 'version magic|module verification failed|failed to load|avb'
adb shell getprop ro.boot.verifiedbootstate
```

Check manually:

- WiFi: turn it on and scan for networks.
- Bluetooth: turn it on and pair a device.
- Touch: test the entire screen area.
- Front and rear cameras.
- Speaker, microphone, and headset audio.
- Sensors: auto-rotate and proximity during a call.
- Charging.

For KSU:

```bash
adb shell su -v
```

Or open **KernelSU-Next Manager v3.4.2**.

## 7. Rollback

### 7.1 Fastboot

```bash
adb reboot bootloader
fastboot flash boot boot-stock.img
fastboot reboot
```

A/B:

```bash
fastboot flash boot_a boot-stock.img
# adjust the slot as needed
```

### 7.2 Recovery

If the device can still boot into recovery:

```bash
adb shell su -c 'dd if=/sdcard/boot-stock.img of=/dev/block/by-name/boot'
```

Or restore the TWRP backup.

### 7.3 Cannot enter recovery or fastboot

This is an emergency. Find the stock firmware (MediaTek scatter file / fastboot
ROM) for the device codename and flash it again. That is why backups and
knowledge of the stock flashing tool are mandatory before trying a custom
kernel.

## 8. AVB / vbmeta

AnyKernel3 uses `PATCH_VBMETA_FLAG=auto`, which is usually enough to keep the
device booting. If a verification error appears:

```bash
fastboot --disable-verity --disable-verification flash vbmeta vbmeta-stock.img
```

Do not flash an empty `vbmeta` without understanding the consequences. Some
MediaTek devices require a `vbmeta` image that matches the firmware.

## 9. Do not mix with the GPU flasher

The `Flasher-Overclock-1.4GHz` folder modifies `vendor_dlkm`
(`mtk_gpufreq_mt6789.ko`). That module is separate from the DarkniusX kernel.

Recommended order:

1. Flash the DarkniusX kernel.
2. Boot and verify.
3. Only then flash the GPU overclock (if desired), with a `vendor_dlkm`
   backup.

Do not flash both at once; if a bootloop occurs, it becomes difficult to
determine the cause.

## 10. Rollback checklist

- [ ] `boot-stock.img` exists and has a reasonable size
- [ ] `vendor_boot-stock.img` exists (if the device has the partition)
- [ ] `vendor_dlkm-stock.img` exists (if using the GPU mod)
- [ ] You know how to enter fastboot/recovery
- [ ] You know the codename and stock firmware
- [ ] You have read the KMI section in `BUILD.md`
