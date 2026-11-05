# Benchmark DarkniusX

Tujuan: membandingkan **stock kernel**, **DarkniusX Vanilla**, dan
**DarkniusX KernelSU Next** secara adil. Hindari kesimpulan dari satu run.

## 1. Kondisi yang harus sama

- Baterai 70–90%, tidak charging saat benchmark CPU/GPU.
- Suhu awal sama (diamkan 15–30 menit di suhu ruang).
- Tidak ada aplikasi berat di latar belakang.
- Brightness dan refresh rate sama.
- Mode performa/battery sama (jika ada).
- Jaringan/WiFi sama untuk benchmark yang butuh network.
- Reboot sekali setelah flash, lalu diamkan 10 menit.

Cek suhu:

```bash
adb shell dumpsys thermalservice
adb shell 'cat /sys/class/thermal/thermal_zone*/temp'
```

## 2. Benchmark yang disarankan

### 2.1 CPU

- **Geekbench 6**: single-core dan multi-core.
- Jalankan 3x, ambil median.
- Catat suhu awal/akhir.

### 2.2 GPU / termal

- **3DMark Wild Life** (atau Wild Life Extreme jika didukung).
- Fokus pada **stability** dan **temperature**, bukan hanya skor.
- Jalankan 3x berturut-turut untuk melihat throttling.

### 2.3 Storage (opsional)

- AndroBench / `fio` jika tersedia.
- Kernel biasanya tidak mengubah storage secara signifikan; jangan jadi
  patokan utama.

### 2.4 Baterai

- Reset stats:
  ```bash
  adb shell dumpsys batterystats --reset
  ```
- Diamkan 8 jam (screen off, WiFi/mobile standby).
- Bandingkan `dumpsys batterystats` dan `dumpsys power`.

## 3. Metrik kernel

```bash
# frekuensi CPU saat idle / load
adb shell 'cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq'

# governor
adb shell 'cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'

# beban
adb shell cat /proc/loadavg

# memori
adb shell free -h

# modul vendor
adb shell cat /proc/modules

# error kernel
adb shell dmesg | grep -iE 'panic|oops|watchdog|kasan|ubsan|kfence|version magic'
```

## 4. Stabilitas

Lakukan minimal:

- 30 menit game / video.
- 1 jam hotspot / WiFi.
- 8 jam idle.
- Reboot 3x.
- Buka kamera, Bluetooth, GPS, NFC (jika ada).

Tidak boleh ada:

- reboot spontan,
- `kernel panic` / `Oops`,
- layar mati permanen,
- WiFi/BT mati setelah sleep,
- touch tidak responsif setelah wake.

## 5. Format pencatatan

Simpan hasil di spreadsheet / markdown:

| Skenario | Stock | Vanilla | KSU |
|---|---|---|---|
| Geekbench 6 single | | | |
| Geekbench 6 multi | | | |
| 3DMark Wild Life | | | |
| Suhu max (game 30m) | | | |
| Baterai idle 8h | | | |
| Boot time | | | |

Sertakan:

- versi kernel (`uname -r`),
- tanggal,
- suhu ruang,
- versi aplikasi benchmark,
- catatan throttling.

## 6. Ekspektasi realistis

- Menghapus `UBSAN`/`KFENCE` bisa mengurangi overhead dan ukuran image,
  tetapi `KASAN` (HW_TAGS), `PAGE_OWNER`, dan `DEBUG_LIST` sengaja tetap
  aktif demi kompatibilitas KMI GKI. Pada perangkat tanpa MTE, KASAN HW_TAGS
  tidak menginstrumentasi semua akses memori, jadi selisih performanya tidak
  selalu besar.
- Perbedaan paling terasa pada ukuran image, waktu build, dan beban memori —
  bukan selalu pada skor benchmark.
- KernelSU menambah sedikit kode di jalur syscall, tetapi overhead harian
  biasanya kecil. Jika terasa besar, cek `CONFIG_KSU_DEBUG` (harus off).
- Throttling termal sering lebih menentukan skor daripada tweak kernel.

## 7. Yang tidak boleh dilakukan

- Membandingkan skor dari suhu/baterai berbeda.
- Menjalankan benchmark saat charging.
- Mengambil satu run terbaik dan menyebutnya "hasil".
- Menyimpulkan performa dari AnTuTu saja.
