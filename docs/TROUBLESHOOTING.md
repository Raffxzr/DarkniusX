# Troubleshooting DarkniusX

## 1. Saat sync / setup

### `repo: command not found`

Arch/CachyOS:

```bash
sudo pacman -S repo
```

Atau pasang launcher:

```bash
mkdir -p ~/.local/bin
curl -LSs https://storage.googleapis.com/git-repo-downloads/repo -o ~/.local/bin/repo
chmod a+x ~/.local/bin/repo
export PATH="$HOME/.local/bin:$PATH"
```

### `repo sync` gagal / koneksi putus

Ulangi dengan job lebih sedikit:

```bash
cd "$HOME/darkniusx/aosp"
repo sync -c -j4 --no-tags --no-clone-bundle --force-sync
```

Jika masih gagal, cek disk:

```bash
df -h "$HOME"
```

### `error: Your local changes to the following files would be overwritten`

Biasanya karena integrasi KernelSU ada di `common/`. Script `setup.sh`
memakai `--force-sync`; jika masih gagal:

```bash
cd "$HOME/darkniusx/aosp/common"
git checkout -f
git reset --hard
```

Lalu jalankan `bash scripts/setup.sh --no-sync`.

### `repo sync` lambat / mentok di prebuilts

Prebuilt clang cukup besar. Pastikan tidak ada proxy yang memblokir
`android.googlesource.com` dan `storage.googleapis.com`. Coba:

```bash
repo sync -c -j2 --no-tags --no-clone-bundle --force-sync prebuilts-master/clang/host/linux-x86
```

## 2. Saat build

### `clang: error: unknown argument` / fitur compiler tidak dikenal

Cek apakah fragment benar-benar terpakai:

```bash
grep -n "CLANG_PREBUILT_BIN" "$HOME/darkniusx/aosp/.darkniusx/build/fragment.sh"
"$HOME/darkniusx/aosp/prebuilts-master/clang/host/linux-x86/clang-r416183b/bin/clang" --version
```

Pastikan `CLANG_PREBUILT_BIN` mengarah ke `clang-r416183b`, bukan
`clang-r563880b`.

Jika source benar-benar membutuhkan compiler lebih baru, unduh
`clang-r563880b` terpisah dan ubah path di `build/fragment.sh`. Jangan
mengubah `build.config.common` langsung; perubahan itu akan hilang saat
overlay.

### `check_defconfig` gagal / `savedefconfig does not match`

Fragment tidak ter-source. Cek:

```bash
grep -n "BUILD_CONFIG_FRAGMENTS" "$HOME/darkniusx/logs/build-"*.log | head
```

Pastikan file ini ada:

```text
$HOME/darkniusx/aosp/.darkniusx/build/fragment.sh
```

dan `POST_DEFCONFIG_CMDS` di file tersebut menimpa `check_defconfig`.

### `ERROR: CONFIG_KSU is not enabled`

Setup KernelSU gagal atau fragment KSU tidak terpakai. Cek:

```bash
cd "$HOME/darkniusx/aosp/common"
ls -l drivers/kernelsu
grep -n kernelsu drivers/Makefile
grep -n 'drivers/kernelsu/Kconfig' drivers/Kconfig
git -C KernelSU-Next describe --tags --exact-match
```

Harus ada symlink, entri Makefile/Kconfig, dan tag `v3.4.2`. Jika tidak:

```bash
cd "$HOME/darkniusx/aosp/common"
curl -LSs https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/v3.4.2/kernel/setup.sh | bash -s v3.4.2
```

### `Killed` / build OOM

Gejala: proses `clang` atau `ld.lld` hilang, log berhenti tanpa error jelas.

Solusi:

```bash
CPUSET=0-1 bash scripts/build.sh vanilla thin
```

atau tambah swap:

```bash
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

Jangan gunakan `LTO=full` dengan RAM 15 GiB dan 6+ job.

### `ld.lld: error: unable to find library -l...`

Biasanya hermetic toolchain / sysroot tidak lengkap. Pastikan sync selesai:

```bash
cd "$HOME/darkniusx/aosp"
repo sync -c -j4 --force-sync build prebuilts/build-tools prebuilts/kernel-build-tools
```

Cek juga `clang-r416183b/bin/ld.lld` ada.

### `Image.lz4` tidak ditemukan setelah build

Build berhenti sebelum tahap copy. Cari error pertama:

```bash
grep -n -iE "error:|fatal:|failed|Killed" "$HOME/darkniusx/logs/build-vanilla-"*.log | head -30
```

### `compare_to_symbol_list` / KMI mismatch

Berarti ada perubahan config yang mengubah exported symbol. Kembalikan
fragment ke baseline, lalu tambahkan perubahan satu per satu. Jangan mematikan
opsi GKI yang memengaruhi ABI (lihat `config/base.config`).

### `modules list out of date`

`CONFIG_KSU=y` seharusnya built-in, bukan module. Jika KSU ter-build sebagai
`m`, ubah menjadi `y`. Cek:

```bash
grep '^CONFIG_KSU=' "$HOME/darkniusx/out/ksu/common/.config"
```

### `taskset: failed to set ... affinity`

Container/host membatasi CPU. Cek CPU yang tersedia:

```bash
taskset -pc $$
nproc
```

Gunakan `CPUSET` yang valid, misalnya `CPUSET=0-1`.

## 3. Saat flashing

### `adb: no devices/emulators found`

```bash
adb kill-server
adb start-server
adb devices
```

Pastikan USB debugging aktif dan authorize RSA key di perangkat.

### Recovery menolak zip (signature verification)

Zip AnyKernel3 tidak ditandatangani dengan key OTA pabrik. Gunakan custom
recovery (TWRP/OrangeFox) atau flash `boot.img` lewat fastboot. Jangan mematikan
verifikasi OTA secara permanen kecuali paham risikonya.

### Bootloop

1. Tunggu 15 menit.
2. Masuk recovery/fastboot.
3. Restore `boot-stock.img`.
4. Jika perlu, restore `vendor_boot`/`vendor_dlkm`.
5. Jangan flash ulang zip yang sama.

Penyebab umum:

- KMI tidak cocok (`android13-11` vs `android12-9`).
- Zip untuk device lain.
- Boot image/header tidak kompatibel.
- `vendor_dlkm` dimodifikasi bersamaan.

### WiFi / Bluetooth / touch mati

Cek:

```bash
adb shell uname -r
adb shell dmesg | grep -iE 'version magic|module verification failed|failed to load'
adb shell cat /proc/modules | grep -iE 'wlan|bt|touch'
```

Jika `uname -r` bukan `android12-9`, kernel salah KMI. Restore boot stock.

Jika module gagal karena vermagic, cek flag:

```bash
adb shell dmesg | grep -i "should be"
```

Dengan `CONFIG_MODVERSIONS`, release string diabaikan; yang dibandingkan
adalah flag setelah spasi. Pastikan tidak mengubah `CONFIG_SMP`,
`CONFIG_PREEMPT`, atau `CONFIG_MODULE_UNLOAD`/`MODVERSIONS`.

### KernelSU Manager bilang "not installed"

- Pastikan memakai **KernelSU-Next Manager**, bukan KernelSU resmi.
- Versi manager harus cocok dengan kernel `v3.4.2`.
- Cek `adb shell su -v`; jika tidak ada, kernel KSU tidak terpasang atau
  manager tidak punya izin.
- Cek `dmesg | grep -i kernelsu`.

### `su` tidak ditemukan

KernelSU tidak menyediakan binary `su` di `/system`; manager yang menyediakan
interface. Gunakan manager yang benar dan grant root ke shell/terminal.

## 4. Log yang perlu dikumpulkan

Saat melaporkan masalah, sertakan:

```bash
uname -r
getprop ro.product.device
getprop ro.board.platform
getprop ro.build.version.release
getprop ro.boot.slot_suffix
dmesg | tail -200
cat /proc/modules | head -50
```

Untuk build:

```text
$HOME/darkniusx/logs/build-<variant>-<timestamp>.log
$HOME/darkniusx/out/<variant>/common/.config
$HOME/darkniusx/artifacts/<variant>/BUILD_INFO.txt
```

## 5. Mulai dari bersih

Jika build tree sudah terlalu berantakan:

```bash
# Hapus output satu varian
rm -rf "$HOME/darkniusx/out/vanilla"
rm -rf "$HOME/darkniusx/artifacts/vanilla"

# Overlay ulang source (tanpa sync)
bash scripts/setup.sh --no-sync

# Build ulang
bash scripts/build.sh vanilla thin
```

Untuk sync ulang total (hati-hati, download besar):

```bash
rm -rf "$HOME/darkniusx/aosp"
bash scripts/setup.sh
```
