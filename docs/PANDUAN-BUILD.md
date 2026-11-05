# Panduan Build DarkniusX

Panduan ini menjelaskan cara membangun kernel **DarkniusX** untuk Android 12 /
GKI Linux 5.10 dari nol di CachyOS (Arch-based), termasuk varian **Vanilla**
dan **KernelSU Next**.

> **Status:** build host untuk kedua varian (Vanilla dan KernelSU Next) sudah
> berhasil, termasuk KMI check. Kernel belum diuji di perangkat fisik. Jangan
> flashing sebelum membaca bagian kompatibilitas dan backup.

---

## 0. Ringkasan

Yang akan dihasilkan:

| File | Isi |
|---|---|
| `Image` | kernel ARM64 tidak terkompresi |
| `Image.lz4` | kernel terkompresi LZ4 (format GKI) |
| `System.map` | simbol kernel |
| `config` | konfigurasi kernel final |
| `DarkniusX-<variant>-5.10.272-<tanggal>.zip` | paket AnyKernel3 untuk flash ke partisi `boot` |

Perkiraan kebutuhan:

- Disk: **30–40 GiB** untuk source + prebuilt, **10–20 GiB per varian** output.
- Waktu sync: 15–60 menit tergantung koneksi.
- Waktu build: **30–60 menit per varian** dengan 4 core dan ThinLTO.
- RAM: 15 GiB cukup untuk ThinLTO; Full LTO sebaiknya 32 GiB+.

---

## 1. Peringatan kompatibilitas (baca dulu)

Project ini hanya untuk:

- Kernel GKI **android12-5.10**, KMI generation **9**.
- Perangkat dengan partisi `boot` (GKI boot image).
- Vendor module yang dibangun untuk KMI generation 9.

Cek di perangkat:

```bash
adb shell uname -r
adb shell getprop ro.product.device
adb shell getprop ro.board.platform
adb shell getprop ro.build.version.release
adb shell getprop ro.build.ab_update
```

Contoh output yang **cocok**:

```text
5.10.269-android12-9-g222b41edc3a2-ab16633388
```

Yang penting adalah bagian `-android12-9-`. Jika outputnya:

```text
5.10.xxx-android13-11-...
```

maka perangkat memakai KMI generation 11 (android13-5.10). **Jangan flash**
kernel ini; vendor module tidak akan cocok.

Cek partisi:

```bash
adb shell 'ls -l /dev/block/by-name | grep -E "boot|vendor_boot|vendor_dlkm|dtbo"'
```

Jika `vendor_boot` atau `vendor_dlkm` tidak ada, beri tahu saya sebelum
melanjutkan; skema flashing-nya bisa berbeda.

> Catatan: `uname -r` yang berbeda **tidak otomatis** merusak vendor module.
> GKI memakai `CONFIG_MODVERSIONS=y`; saat memuat module, kernel mengabaikan
> token pertama (nama release) dan hanya membandingkan flag vermagic serta
> CRC simbol. Jadi `5.10.272-DarkniusX` tetap bisa memuat module yang dibangun
> untuk `5.10.269-android12-9`. Yang **tidak boleh** berubah adalah layout
> struct dan CRC simbol GKI.

---

## 2. Prasyarat

- CachyOS/Arch Linux (host) dengan `sudo`.
- 8 core CPU (4 core masih bisa, lebih lambat).
- RAM 15 GiB + swap.
- Ruang kosong di filesystem Linux (ext4/btrfs) minimal 80 GiB.
- Kabel USB + `adb`/`fastboot` untuk flashing.
- Perangkat sudah unlock bootloader dan punya cara restore `boot` (fastboot
  atau custom recovery).

**Jangan build di `/mnt/sdb2`** jika filesystem-nya NTFS. Source kernel
membutuhkan symlink, permission, dan case sensitivity. Workspace default
`$HOME/darkniusx` berada di Btrfs.

Cek:

```bash
findmnt -no FSTYPE --target "$HOME"
df -h "$HOME"
free -h
nproc
```

---

## 3. Siapkan project

Project ini berada di:

```text
/mnt/sdb2/Documents/Project/Raff/DarkniusX
```

Folder tersebut hanya berisi script/config (file teks), jadi aman di NTFS.
Yang dipindahkan ke Btrfs hanyalah workspace build (`$HOME/darkniusx`).

```bash
cd /mnt/sdb2/Documents/Project/Raff/DarkniusX
chmod +x scripts/*.sh 2>/dev/null || true
```

Di NTFS `chmod` mungkin tidak berpengaruh; semua script tetap bisa dijalankan
dengan `bash scripts/...`.

---

## 4. Instal dependensi host

```bash
bash scripts/install-deps.sh
```

Script akan memakai `pacman` di Arch/CachyOS. Paket penting:

```text
base-devel git repo make bc bison flex cpio rsync zip unzip lz4 dtc
python3 curl openssl libelf ncurses
```

Kalau tidak ingin memakai script:

```bash
sudo pacman -S --needed base-devel git repo make bc bison flex cpio rsync \
  zip unzip lz4 dtc python curl openssl libelf ncurses
```

Cek:

```bash
repo --version
clang --version        # clang host tidak dipakai, tapi berguna untuk cek
```

> **Opsi distrobox:** jika tidak ingin menambah paket di host, gunakan
> container Ubuntu 22.04 (`gki-builder`) yang sudah ada, lalu instal
> `git repo make bc bison flex cpio libelf-dev libssl-dev libncurses-dev
> rsync zip unzip lz4 device-tree-compiler python3 curl`. Build tetap harus
> di `$HOME` (Btrfs), bukan di `/mnt/sdb2`.

---

## 5. Sync source AOSP + overlay fork

```bash
bash scripts/setup.sh
```

Yang dilakukan script:

1. `repo init` manifest `kernel/manifest` branch `common-android12-5.10`
   dengan `--depth=1`.
2. `repo sync -c -j8 --no-tags --no-clone-bundle --force-sync`.
3. Overlay `common/` dengan fork:
   - remote `darkniusx` → `https://github.com/lifeats666ln/kernel_common-5.10.git`
   - fetch branch `android12-5.10`
   - checkout commit `f04d8c2a2f78a836d81d7ab0c1ab675f4ddddc9f`
4. Menyalin config fragment ke `aosp/.darkniusx/`.

Hasil:

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

Cek versi source:

```bash
git -C "$HOME/darkniusx/aosp/common" log -1 --oneline
grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL) =' "$HOME/darkniusx/aosp/common/Makefile"
```

Harus terlihat commit `f04d8c2` dan Linux `5.10.272`.

### Kenapa compiler di-override?

Fork memakai `build.config.common` dari ACK yang lebih baru dan meminta
`clang-r563880b`. Manifest `common-android12-5.10` hanya menyediakan
`clang-r416183b` (compiler yang memang dipakai branch AOSP ini).

`build/fragment.sh` menimpa:

```bash
CLANG_PREBUILT_BIN=prebuilts-master/clang/host/linux-x86/clang-r416183b/bin
```

Cek compiler:

```bash
"$HOME/darkniusx/aosp/prebuilts-master/clang/host/linux-x86/clang-r416183b/bin/clang" --version
```

Jika suatu saat build gagal karena fitur compiler, baru pertimbangkan
mengunduh `clang-r563880b` terpisah. Untuk source 5.10.272 yang berbasis
branch AOSP ini, `r416183b` seharusnya cukup.

---

## 6. Build varian Vanilla

```bash
bash scripts/build.sh vanilla thin
```

Penjelasan:

- `thin` = ThinLTO, jauh lebih hemat RAM daripada Full LTO.
- Default `CPUSET=0-3` → 4 job build. Untuk 6 job:
  ```bash
  CPUSET=0-5 bash scripts/build.sh vanilla thin
  ```
- Script menjalankan `mrproper` setiap build. Untuk build ulang cepat tanpa
  menghapus output:
  ```bash
  SKIP_MRPROPER=1 bash scripts/build.sh vanilla thin
  ```

Alur internal:

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

Log build:

```text
$HOME/darkniusx/logs/build-vanilla-YYYYMMDD-HHMMSS.log
```

### Full LTO (opsional, untuk release)

```bash
CPUSET=0-3 bash scripts/build.sh vanilla full
```

Full LTO membutuhkan RAM jauh lebih besar. Dengan 15 GiB dan 4 job, risiko
OOM tinggi. Gunakan hanya jika yakin, atau tambah swap:

```bash
sudo swapon --show
```

Untuk hasil harian, `thin` sudah cukup; perbedaan performa runtime biasanya
kecil.

---

## 7. Build varian KernelSU Next

```bash
bash scripts/build.sh ksu thin
```

Yang dilakukan:

1. Menjalankan `KernelSU-Next/kernel/setup.sh v3.4.2` dari folder
   `aosp/common`.
2. Setup membuat symlink `drivers/kernelsu` dan menambahkan entri di
   `drivers/Makefile` + `drivers/Kconfig`.
3. Config efektif = `config/base.config` + `config/ksu.config`
   (`CONFIG_KSU=y`).
4. Build seperti biasa.

Verifikasi di log:

```text
-- KernelSU-Next version: ...
-- KernelSU-Next tag: v3.4.2
```

Catatan penting:

- KernelSU Next `v3.4.2` **tidak** memakai `CONFIG_KSU_KPROBES_HOOK`.
  Dokumentasi lama menyebut simbol itu; menambahkannya tidak berguna.
- `CONFIG_KPROBES=y` dan `CONFIG_EXT4_FS=y` sudah ada di `gki_defconfig`.
- Gunakan **KernelSU-Next Manager** versi yang cocok (`v3.4.2`), bukan
  aplikasi KernelSU resmi. Manager yang salah akan melaporkan "KernelSU not
  installed" walaupun kernel sudah benar.

Output:

```text
$HOME/darkniusx/artifacts/ksu/DarkniusX-ksu-5.10.272-YYYYMMDD.zip
```

---

## 8. Verifikasi hasil build

### 8.1 Cek file dan ukuran

```bash
ls -lh "$HOME/darkniusx/out/vanilla/dist/"
ls -lh "$HOME/darkniusx/artifacts/vanilla/"
```

Ukuran kasar:

- `Image` : 30–45 MB
- `Image.lz4` : 10–16 MB
- zip : 15–25 MB

Jika `Image` hanya beberapa MB, build gagal / `MAKE_GOALS` salah.

### 8.2 Cek config final

```bash
CONFIG="$HOME/darkniusx/out/vanilla/common/.config"
grep -E '^CONFIG_LOCALVERSION=|^CONFIG_KASAN=|^CONFIG_KASAN_HW_TAGS=|^CONFIG_PAGE_OWNER=|^CONFIG_DEBUG_LIST=|^CONFIG_UBSAN=|^CONFIG_KFENCE=|^CONFIG_SCHEDSTATS=|^CONFIG_SCHED_DEBUG=' "$CONFIG"
```

Harapan:

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

`KASAN`/`KASAN_HW_TAGS`, `PAGE_OWNER`, `DEBUG_LIST`, `SCHEDSTATS`, dan
`SCHED_DEBUG` sengaja tetap `y`: simbolnya ada di daftar KMI GKI dan/atau
opsinya mengubah layout struct yang dipakai vendor module. Yang dimatikan
hanya `UBSAN` dan `KFENCE` karena keduanya murni instrumentasi debug tanpa
simbol KMI.

Untuk KSU:

```bash
grep -E '^CONFIG_KSU=|^CONFIG_KSU_DEBUG=' "$HOME/darkniusx/out/ksu/common/.config"
```

Harapan:

```text
CONFIG_KSU=y
# CONFIG_KSU_DEBUG is not set
```

### 8.3 Cek release string

Kernel belum dijalankan, tapi `include/config/kernel.release` bisa dicek:

```bash
cat "$HOME/darkniusx/out/vanilla/common/include/config/kernel.release"
```

Harapan:

```text
5.10.272-DarkniusX
```

### 8.4 Cek KMI

```bash
ls -lh "$HOME/darkniusx/out/vanilla/dist/abi.xml" \
       "$HOME/darkniusx/out/vanilla/dist/abi.prop" 2>/dev/null
```

Build GKI menjalankan pemeriksaan KMI. Jika build selesai, symbol list dan
ABI check sudah lolos.

---

## 9. Packaging dan device check

Build script otomatis memanggil `scripts/package.sh`. Untuk packaging ulang
tanpa rebuild:

```bash
bash scripts/package.sh vanilla
bash scripts/package.sh ksu
```

### Aktifkan device check

Sangat disarankan agar zip menolak terpasang di device yang salah:

```bash
DEVICE_NAME=X6853 bash scripts/package.sh vanilla
```

`DEVICE_NAME` harus sama dengan `ro.product.device` perangkat (case-sensitive).
Beberapa perangkat Infinix memakai nama seperti `Infinix-X6853`; cek:

```bash
adb shell getprop ro.product.device
```

Jika `DEVICE_NAME` tidak diisi, `do.devicecheck=0` dan zip bisa terpasang di
device apa pun. Ini berbahaya; hanya gunakan untuk testing terkontrol.

### Isi zip

```text
anykernel.sh
Image
META-INF/
tools/
```

`anykernel.sh` memakai `BLOCK=boot`, `IS_SLOT_DEVICE=1`, dan hanya mengganti
kernel di partisi `boot`. Ramdisk, `vendor_boot`, `vendor_dlkm`, dan `dtbo`
tidak disentuh.

---

## 10. Backup dan flashing

> Bagian ini generik. Tanpa detail perangkat (codename, slot, recovery),
> perintah bisa berbeda. Kirim output bagian 1 untuk instruksi yang tepat.

### 10.1 Backup partisi

Backup minimal `boot`; lebih aman `boot`, `vendor_boot`, `vendor_dlkm`, dan
`dtbo`.

Cek nama partisi:

```bash
adb shell 'ls -l /dev/block/by-name/ | grep -E "boot|vendor_boot|vendor_dlkm|dtbo"'
```

Backup (perangkat harus root / adb root):

```bash
adb shell su -c 'dd if=/dev/block/by-name/boot of=/sdcard/boot-stock.img'
adb shell su -c 'dd if=/dev/block/by-name/vendor_boot of=/sdcard/vendor_boot-stock.img'
adb shell su -c 'dd if=/dev/block/by-name/vendor_dlkm of=/sdcard/vendor_dlkm-stock.img'
adb pull /sdcard/boot-stock.img
adb pull /sdcard/vendor_boot-stock.img
adb pull /sdcard/vendor_dlkm-stock.img
```

Untuk perangkat A/B, `by-name/boot` biasanya symlink ke slot aktif. Cek:

```bash
adb shell getprop ro.boot.slot_suffix
adb shell 'readlink -f /dev/block/by-name/boot'
```

Simpan backup di komputer, bukan hanya `/sdcard`.

### 10.2 Flash lewat custom recovery

Cara paling umum untuk zip AnyKernel3:

```bash
adb reboot recovery
# di recovery: Advanced -> ADB Sideload
adb sideload DarkniusX-vanilla-5.10.272-YYYYMMDD.zip
```

Atau:

```bash
adb push DarkniusX-vanilla-5.10.272-YYYYMMDD.zip /sdcard/
# di recovery: Install -> pilih zip
```

Jika recovery stok menolak zip (signature verification), gunakan custom
recovery (TWRP/OrangeFox) atau flash `boot.img` lewat fastboot. Zip ini tidak
ditandatangani dengan key OTA pabrik.

### 10.3 First boot

- Boot pertama bisa 5–10 menit (dex2oat / verifikasi).
- Perangkat mungkin reboot sekali.
- Jika bootloop lebih dari 15 menit, restore backup.

### 10.4 Verifikasi setelah boot

```bash
adb shell uname -r
# 5.10.272-DarkniusX

adb shell cat /proc/modules | head
adb shell dmesg | grep -iE 'version magic|module verification failed|failed to load'
adb shell getprop ro.boot.verifiedbootstate
```

Cek fungsi penting:

- WiFi dan Bluetooth menyala.
- Touchscreen responsif.
- Kamera, audio, dan sensor bekerja.
- Tidak ada reboot mendadak saat idle.

Untuk KSU:

```bash
adb shell su -v
# atau buka KernelSU-Next Manager
```

### 10.5 Rollback

Jika bootloader fastboot tersedia:

```bash
adb reboot bootloader
fastboot flash boot boot-stock.img
fastboot reboot
```

A/B:

```bash
fastboot flash boot_a boot-stock.img
# atau boot_b sesuai slot aktif
```

Jika fastboot tidak tersedia, restore lewat recovery:

```bash
adb shell su -c 'dd if=/sdcard/boot-stock.img of=/dev/block/by-name/boot'
```

---

## 11. Benchmark

Lakukan di kondisi yang sama (suhu, baterai, aplikasi latar belakang) dan
bandingkan:

1. Stock kernel
2. DarkniusX Vanilla
3. DarkniusX KSU

Minimal:

```bash
adb shell dumpsys thermalservice
adb shell cat /proc/loadavg
adb shell 'cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq'
```

Aplikasi:

- Geekbench 6 (CPU)
- 3DMark Wild Life (GPU/termal)
- AnTuTu (opsional, skor sering berubah)
- `fio`/AndroBench untuk storage (opsional)

Jalankan 3x, ambil median, dan tunggu perangkat dingin di antara run. Jangan
menyimpulkan dari satu run.

Detail: [`BENCHMARK.md`](BENCHMARK.md).

---

## 12. Update source dan reproducibility

### Update fork

Fork di-pin ke commit tertentu di `scripts/env.sh`:

```bash
FORK_COMMIT="f04d8c2a2f78a836d81d7ab0c1ab675f4ddddc9f"
```

Untuk update yang disengaja:

```bash
git ls-remote https://github.com/lifeats666ln/kernel_common-5.10.git refs/heads/android12-5.10
```

Ganti `FORK_COMMIT` dengan hash baru, lalu:

```bash
bash scripts/setup.sh --no-sync
```

Script akan menolak overlay jika HEAD fork tidak sama dengan pin; ini
mencegah update tidak sengaja.

### Update AOSP manifest

```bash
bash scripts/setup.sh
```

`repo sync` akan mengikuti branch manifest terbaru. Setelah update, build
ulang dan uji.

### Simpan revisi terkunci

```bash
bash scripts/freeze.sh
```

Output berisi `manifest.xml` (semua project di-pin ke SHA), `versions.txt`,
dan config yang dipakai. Simpan folder ini bersama release.

---

## 13. Troubleshooting

Lihat [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) untuk daftar lengkap. Beberapa
yang sering:

| Gejala | Penyebab / solusi |
|---|---|
| `repo: command not found` | `sudo pacman -S repo` atau launcher `~/.local/bin/repo` |
| `clang: error: unknown argument` | Pastikan `CLANG_PREBUILT_BIN` mengarah ke `clang-r416183b`; cek `build/fragment.sh` |
| `check_defconfig` gagal | Fragment tidak ter-source; cek `BUILD_CONFIG_FRAGMENTS` dan path `.darkniusx/build/fragment.sh` |
| `CONFIG_KSU` tidak aktif | Setup KernelSU gagal; cek symlink `common/drivers/kernelsu` dan `drivers/Kconfig` |
| Build OOM / `Killed` | Pakai `LTO=thin`, `CPUSET=0-1`, tutup aplikasi, tambah swap |
| `Image.lz4` tidak ada | Build gagal sebelum tahap copy; cari error pertama di log |
| Bootloop | Restore `boot-stock.img`; jangan flash zip tanpa backup |
| WiFi/BT mati | Cek `uname -r` harus `android12-9`; cek `dmesg` untuk module load failure |
| KSU Manager "not installed" | Pakai KernelSU-Next Manager v3.4.2, bukan manager resmi |
| `verity`/`vbmeta` error | AnyKernel3 `PATCH_VBMETA_FLAG=auto`; jika perlu flash `vbmeta` dengan disable-verity |

---

## 14. Checklist sebelum release

- [ ] `uname -r` di perangkat = `5.10.272-DarkniusX`
- [ ] Tidak ada `version magic` / `module verification failed` di `dmesg`
- [ ] WiFi, Bluetooth, touch, kamera, audio, sensor bekerja
- [ ] Tidak ada reboot spontan setelah 24 jam
- [ ] Benchmark stock vs Vanilla vs KSU tercatat
- [ ] `DEVICE_NAME` di-set saat packaging
- [ ] Backup `boot`/`vendor_boot`/`vendor_dlkm` tersimpan
- [ ] `freeze.sh` dijalankan dan manifest disimpan
- [ ] Zip diunggah ke GitHub Releases beserta `SHA256SUMS` dan `BUILD_INFO.txt`

---

## 15. Catatan tentang konfigurasi performa

Fork `lifeats666ln` sudah membawa banyak tweak di `gki_defconfig`:

- `CONFIG_PREEMPT=y`
- `CONFIG_TCP_CONG_BBR=y`, CUBIC dimatikan
- `CONFIG_DEFAULT_FQ_CODEL=y`
- `CONFIG_MQ_IOSCHED_ADIOS=y`, BFQ
- `CONFIG_PELT_UTIL_HALFLIFE_12=y`
- `CONFIG_RT_SOFTINT_OPTIMIZATION=y`
- `CONFIG_DAMON=y` (reclaim)
- `CONFIG_LTO_CLANG_FULL=y`, `CONFIG_CFI_CLANG=y`

Karena itu, fragment DarkniusX **tidak** menambahkan tweak agresif baru.
Fokusnya adalah menghapus overhead debug yang tidak perlu tanpa merusak ABI.
Jika ingin eksperimen lebih agresif, buat fragment terpisah dan uji satu
perubahan pada satu waktu; jangan langsung menumpuk banyak opsi.
