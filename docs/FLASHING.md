# Flashing dan Rollback

Panduan ini generik untuk perangkat GKI `android12-5.10`. Perintah partisi bisa
berbeda tergantung codename dan layout A/B. **Selalu cek nama partisi di
perangkat sebelum menjalankan `dd`.**

## 1. Sebelum mulai

Yang harus tersedia:

- Bootloader sudah unlock (atau custom recovery terpasang).
- `adb` dan `fastboot` di komputer.
- Backup `boot`, `vendor_boot`, `vendor_dlkm`, dan `dtbo` (jika ada).
- Zip kernel DarkniusX.
- Kernel stock / boot image cadangan untuk rollback.

Cek koneksi:

```bash
adb devices
adb shell getprop ro.product.device
adb shell getprop ro.boot.slot_suffix
adb shell uname -r
```

`uname -r` harus mengandung `-android12-9-`.

## 2. Cek partisi

```bash
adb shell 'ls -l /dev/block/by-name/ | grep -E "boot|vendor_boot|vendor_dlkm|dtbo"'
```

Contoh perangkat A/B:

```text
boot_a -> /dev/block/sde12
boot_b -> /dev/block/sde13
vendor_boot_a -> /dev/block/sde14
vendor_boot_b -> /dev/block/sde15
vendor_dlkm_a -> /dev/block/sde16
vendor_dlkm_b -> /dev/block/sde17
```

`/dev/block/by-name/boot` biasanya symlink ke slot aktif. Jangan menebak; cek
`readlink -f`.

## 3. Backup

### 3.1 Dengan root (paling mudah)

```bash
adb shell su -c 'dd if=/dev/block/by-name/boot of=/sdcard/boot-stock.img'
adb shell su -c 'dd if=/dev/block/by-name/vendor_boot of=/sdcard/vendor_boot-stock.img'
adb shell su -c 'dd if=/dev/block/by-name/vendor_dlkm of=/sdcard/vendor_dlkm-stock.img'
adb pull /sdcard/boot-stock.img
adb pull /sdcard/vendor_boot-stock.img
adb pull /sdcard/vendor_dlkm-stock.img
```

Jika root belum ada, gunakan custom recovery (TWRP/OrangeFox) → Backup →
pilih `Boot`, `Vendor Boot`, `Vendor DLKM`.

### 3.2 Verifikasi backup

```bash
ls -lh boot-stock.img vendor_boot-stock.img vendor_dlkm-stock.img
file boot-stock.img
```

Ukuran `boot-stock.img` biasanya 32–128 MB. Simpan juga salinan di komputer
lain / cloud.

## 4. Flash kernel

### 4.1 Custom recovery (disarankan untuk zip AnyKernel3)

```bash
adb reboot recovery
```

Di recovery:

- TWRP/OrangeFox: **Install** → pilih zip.
- Atau **Advanced → ADB Sideload**, lalu:

```bash
adb sideload DarkniusX-vanilla-5.10.272-YYYYMMDD.zip
```

Jangan wipe data. Zip hanya mengganti kernel di `boot`.

### 4.2 Fastboot (jika punya boot.img)

Zip AnyKernel3 bukan `boot.img`. Jika ingin flash lewat fastboot, ekstrak
`Image` dari zip dan buat boot image dengan tool yang sesuai, atau gunakan
`fastboot boot` pada boot image yang sudah dibuat. Cara ini lebih berisiko
karena harus mempertahankan header/ramdisk stock.

Untuk perangkat dengan `init_boot` (Android 13+), kernel tetap berada di
`boot`; jangan flash `init_boot`.

## 5. First boot

- 5–10 menit normal.
- Layar mungkin hitam / logo diam beberapa menit.
- Jangan langsung panik dan reboot paksa sebelum 15 menit.
- Jika reboot berulang (bootloop) lebih dari 15 menit, restore.

## 6. Verifikasi setelah boot

```bash
adb shell uname -r
adb shell cat /proc/modules | wc -l
adb shell dmesg | grep -iE 'version magic|module verification failed|failed to load|avb'
adb shell getprop ro.boot.verifiedbootstate
```

Cek manual:

- WiFi: nyalakan, cari jaringan.
- Bluetooth: nyalakan, pairing.
- Touch: seluruh area layar.
- Kamera depan/belakang.
- Audio speaker, mic, headset.
- Sensor: auto-rotate, proximity saat telepon.
- Charging.

Untuk KSU:

```bash
adb shell su -v
```

Atau buka **KernelSU-Next Manager v3.4.2**.

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
# sesuaikan slot
```

### 7.2 Recovery

Jika perangkat masih bisa masuk recovery:

```bash
adb shell su -c 'dd if=/sdcard/boot-stock.img of=/dev/block/by-name/boot'
```

Atau restore backup TWRP.

### 7.3 Tidak bisa masuk recovery/fastboot

Ini keadaan darurat. Cari firmware stock (scatter file MediaTek / fastboot
ROM) untuk codename perangkat dan flash ulang. Karena itu, backup dan
pengetahuan tentang tool flashing stock wajib sebelum mencoba.

## 8. AVB / vbmeta

AnyKernel3 memakai `PATCH_VBMETA_FLAG=auto`, yang biasanya cukup untuk
mempertahankan boot. Jika muncul error verifikasi:

```bash
fastboot --disable-verity --disable-verification flash vbmeta vbmeta-stock.img
```

Jangan flash `vbmeta` kosong tanpa memahami konsekuensinya. Beberapa perangkat
MediaTek membutuhkan `vbmeta` yang cocok dengan firmware.

## 9. Jangan dicampur dengan flasher GPU

Folder `Flasher-Overclock-1.4GHz` memodifikasi `vendor_dlkm`
(`mtk_gpufreq_mt6789.ko`). Itu modul terpisah dari kernel DarkniusX.

Urutan yang disarankan:

1. Flash kernel DarkniusX.
2. Boot dan verifikasi.
3. Baru flash GPU overclock (jika mau), dengan backup `vendor_dlkm`.

Jangan flash keduanya sekaligus; jika terjadi bootloop, sulit menentukan
penyebabnya.

## 10. Checklist rollback

- [ ] `boot-stock.img` ada dan ukurannya wajar
- [ ] `vendor_boot-stock.img` ada (jika perangkat punya)
- [ ] `vendor_dlkm-stock.img` ada (jika memakai GPU mod)
- [ ] Tahu cara masuk fastboot/recovery
- [ ] Tahu codename dan firmware stock
- [ ] Sudah baca bagian KMI di `PANDUAN-BUILD.md`
