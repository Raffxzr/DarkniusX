# DarkniusX

Kernel GKI **Linux 5.10 (android12-5.10)** yang difokuskan untuk stabilitas dan performa harian, tersedia dalam dua varian:

| Varian | Root | Keterangan |
|---|---|---|
| **Vanilla** | Tidak | Kernel bersih, tanpa KernelSU |
| **KernelSU Next** | Ya | Kernel + KernelSU Next `v3.4.2` (built-in, `CONFIG_KSU=y`) |

## Basis

- AOSP common kernel: `common-android12-5.10` (KMI generation **9**)
- Fork sumber: [`lifeats666ln/kernel_common-5.10`](https://github.com/lifeats666ln/kernel_common-5.10) branch `android12-5.10`
- Commit yang di-pin: `f04d8c2a2f78a836d81d7ab0c1ab675f4ddddc9f` (Linux **5.10.272**)
- Toolchain: AOSP Clang `r416183b` dari manifest `common-android12-5.10`
- Build system: legacy `build/build.sh` (bukan Kleaf)

## Perubahan utama

- Branding `uname -r` menjadi `5.10.272-DarkniusX` (release token aman karena `CONFIG_MODVERSIONS=y`).
- Menghapus instrumentasi debug yang tidak termasuk kontrak KMI GKI:
  `UBSAN`, `KFENCE`.
- **Tidak** mematikan `KASAN`/`KASAN_HW_TAGS`, `PAGE_OWNER`, `DEBUG_LIST`,
  `SCHEDSTATS`, dan `SCHED_DEBUG`: opsi tersebut menyediakan simbol KMI GKI
  dan/atau mengubah layout `struct task_struct`/`struct sched_entity`. Vendor
  module di perangkat dikompilasi terhadap layout GKI stok, jadi menonaktifkan
  opsi ini bisa menggagalkan KMI check atau membuat module membaca offset yang
  salah.
- Mempertahankan fitur keamanan inti GKI: `CFI_CLANG`, `SHADOW_CALL_STACK`,
  `HARDENED_USERCOPY`, `INIT_ON_ALLOC_DEFAULT_ON`, `MODVERSIONS`, SELinux.
- Varian KernelSU memakai KernelSU Next `v3.4.2` dengan hook kprobes/LSM
  bawaan, bukan patch manual.

## Mulai cepat

Semua perintah dijalankan dari folder project ini:

```bash
# 1. Cek/instal dependensi host (Arch/CachyOS)
bash scripts/install-deps.sh

# 2. Sync AOSP + overlay fork (sekali saja, butuh beberapa GB)
bash scripts/setup.sh

# 3. Build varian Vanilla (ThinLTO, aman untuk RAM 15 GiB)
bash scripts/build.sh vanilla thin

# 4. Build varian KernelSU Next
bash scripts/build.sh ksu thin

# atau keduanya sekaligus
bash scripts/build.sh all thin
```

Hasil build dan zip AnyKernel3 ada di:

```text
$HOME/darkniusx/artifacts/vanilla/
$HOME/darkniusx/artifacts/ksu/
```

Panduan lengkap (Indonesia): [`docs/PANDUAN-BUILD.md`](docs/PANDUAN-BUILD.md)

## Kompatibilitas perangkat

Project ini **hanya** untuk perangkat yang memakai GKI `android12-5.10`
(KMI generation 9). Cek sebelum flashing:

```bash
adb shell uname -r
# harus mengandung: -android12-9-
```

Jika hasilnya `android13-11` atau KMI lain, **jangan flash**. Vendor module
tidak akan cocok.

Perangkat target harus punya partisi `boot` (dan biasanya `vendor_boot` serta
`vendor_dlkm`). Selalu backup `boot`, `vendor_boot`, dan `vendor_dlkm` sebelum
mencoba kernel kustom.

## Struktur project

```text
DarkniusX/
├── build/fragment.sh       # hook BUILD_CONFIG_FRAGMENTS untuk build AOSP
├── config/
│   ├── base.config         # fragment config bersama (Vanilla)
│   └── ksu.config          # tambahan CONFIG_KSU=y
├── docs/
│   ├── PANDUAN-BUILD.md    # panduan build lengkap (Indonesia)
│   ├── FLASHING.md         # backup, flash, rollback
│   ├── BENCHMARK.md        # cara membandingkan performa
│   └── TROUBLESHOOTING.md  # error umum
├── flasher/anykernel.sh    # template AnyKernel3 (kernel-only)
├── RELEASE_NOTES.md        # template catatan rilis
└── scripts/
    ├── env.sh              # konfigurasi & helper
    ├── install-deps.sh
    ├── setup.sh            # repo sync + overlay fork
    ├── build.sh            # build + package
    ├── package.sh          # artifact + zip AnyKernel3
    └── freeze.sh           # simpan manifest/revisi terkunci
```

## Peringatan

- Ini bukan proyek GPU overclock. Folder `Flasher-Overclock-1.4GHz` adalah
  modul `vendor_dlkm` terpisah; jangan dicampur ke zip kernel ini.
- Build harus berada di filesystem Linux (ext4/btrfs). Jangan build di
  `/mnt/sdb2` yang NTFS.
- Kernel kustom selalu punya risiko bootloop. Backup partisi `boot` sebelum
  flashing.
- Status saat ini: build Vanilla dan KernelSU Next sudah berhasil di host
  (termasuk KMI check) dan artifact tersedia di `artifacts/`. Kernel belum
  diuji di perangkat fisik; verifikasi `uname -r`, module vendor, WiFi/BT, dan
  touch setelah flash.

## Lisensi

Kernel source mengikuti lisensi GPL-2.0 dari Linux/AOSP. Script dan config
project ini dilisensikan GPL-2.0-only.
