# DarkniusX v1.0.0 (Linux 5.10.272)

> **Status: pre-release.** Build host untuk kedua varian berhasil dan lolos
> KMI check, tetapi kernel **belum diuji di perangkat fisik**. Jangan flashing
> tanpa backup `boot` dan pahami risiko bootloop.

Kernel GKI `android12-5.10` (KMI generation **9**) yang bersifat **universal**:
bisa dipakai di perangkat apa pun dengan KMI 9, tanpa terikat codename.
Tersedia dua varian: **Vanilla** dan **KernelSU Next**.

## Isi rilis

- Base: AOSP `common-android12-5.10` + fork `lifeats666ln/kernel_common-5.10`
- Source commit: `f04d8c2a2f78a836d81d7ab0c1ab675f4ddddc9f`
- Linux: `5.10.272`
- `uname -r`: `5.10.272-DarkniusX`
- Toolchain: AOSP Clang `r416183b`
- LTO: ThinLTO (kecuali disebut lain)
- KernelSU Next: `v3.4.2` (varian KSU, built-in `CONFIG_KSU=y`)

## File

| File | Varian | Keterangan |
|---|---|---|
| `DarkniusX-vanilla-5.10.272-YYYYMMDD.zip` | Vanilla | Tanpa root |
| `DarkniusX-ksu-5.10.272-YYYYMMDD.zip` | KernelSU Next | Root via KernelSU-Next Manager |
| `SHA256SUMS` | Keduanya | Checksum |

## Kompatibilitas

- **Universal** untuk semua perangkat dengan GKI `android12-5.10` (KMI 9);
  tidak ada device/codename check (`do.devicecheck=0`).
- Wajib: `uname -r` stock mengandung `-android12-9-` (atau kernel DarkniusX
  sebelumnya) **dan** kernel berada di partisi `boot`.
- **Tidak kompatibel** dengan `-android13-11-`, KMI lain, atau perangkat yang
  kernel-nya hanya ada di `vendor_boot`.
- Zip AnyKernel3 hanya mengganti kernel di partisi `boot`; tidak menyentuh
  `vendor_boot`, `vendor_dlkm`, `dtbo`, atau modul GPU overclock.
- Installer membatalkan flash otomatis jika guard KMI tidak terpenuhi.

Cek perangkat sebelum flashing:

```bash
adb shell uname -r
adb shell getprop ro.product.device
adb shell getprop ro.board.platform
```

## Cara flash

Lihat [`docs/FLASHING.md`](docs/FLASHING.md). Ringkasnya:

1. Backup `boot` (dan `vendor_boot`/`vendor_dlkm` jika ada).
2. Flash zip lewat custom recovery (TWRP/OrangeFox) atau sideload.
3. Boot, lalu verifikasi `uname -r`, WiFi/BT, touch, kamera, dan audio.

## Known issues

- Belum diuji pada perangkat fisik pada rilis pertama; lihat catatan status di
  README.
- `KASAN`/`KASAN_HW_TAGS`, `PAGE_OWNER`, `DEBUG_LIST`, `SCHEDSTATS`, dan
  `SCHED_DEBUG` tetap aktif demi kompatibilitas KMI GKI.
- Full LTO tidak disarankan untuk mesin dengan RAM < 32 GiB.

## Rollback

Restore `boot-stock.img` lewat fastboot atau recovery:

```bash
fastboot flash boot boot-stock.img
fastboot reboot
```

## Checksum

Lihat file `SHA256SUMS` pada halaman rilis ini.
