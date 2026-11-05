# Benchmarking DarkniusX

Goal: compare the **stock kernel**, **DarkniusX Vanilla**, and
**DarkniusX KernelSU Next** fairly. Never draw conclusions from a single run.

## 1. Conditions that must match

- Battery at 70–90%, not charging during CPU/GPU benchmarks.
- Same starting temperature (rest the device for 15–30 minutes at room
  temperature).
- No heavy apps in the background.
- Same brightness and refresh rate.
- Same performance/battery mode (if available).
- Same network/WiFi for network-dependent benchmarks.
- Reboot once after flashing, then leave the device idle for 10 minutes.

Check the temperature:

```bash
adb shell dumpsys thermalservice
adb shell 'cat /sys/class/thermal/thermal_zone*/temp'
```

## 2. Recommended benchmarks

### 2.1 CPU

- **Geekbench 6**: single-core and multi-core.
- Run 3 times and take the median.
- Record the starting and ending temperature.

### 2.2 GPU / thermal

- **3DMark Wild Life** (or Wild Life Extreme if supported).
- Focus on **stability** and **temperature**, not just the score.
- Run 3 times in a row to observe throttling.

### 2.3 Storage (optional)

- AndroBench / `fio` if available.
- The kernel usually does not change storage performance significantly; do not
  use it as the main metric.

### 2.4 Battery

- Reset stats:
  ```bash
  adb shell dumpsys batterystats --reset
  ```
- Leave the device idle for 8 hours (screen off, WiFi/mobile standby).
- Compare `dumpsys batterystats` and `dumpsys power`.

## 3. Kernel metrics

```bash
# CPU frequency at idle / load
adb shell 'cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq'

# governor
adb shell 'cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'

# load
adb shell cat /proc/loadavg

# memory
adb shell free -h

# vendor modules
adb shell cat /proc/modules

# kernel errors
adb shell dmesg | grep -iE 'panic|oops|watchdog|kasan|ubsan|kfence|version magic'
```

## 4. Stability

At minimum, run:

- 30 minutes of gaming / video.
- 1 hour of hotspot / WiFi.
- 8 hours idle.
- 3 reboots.
- Open the camera, Bluetooth, GPS, and NFC (if available).

None of the following may occur:

- spontaneous reboots,
- `kernel panic` / `Oops`,
- a permanently black screen,
- WiFi/BT failing after sleep,
- an unresponsive touchscreen after wake.

## 5. Recording format

Store the results in a spreadsheet or Markdown table:

| Scenario | Stock | Vanilla | KSU |
|---|---|---|---|
| Geekbench 6 single | | | |
| Geekbench 6 multi | | | |
| 3DMark Wild Life | | | |
| Max temperature (30m game) | | | |
| 8h idle battery | | | |
| Boot time | | | |

Include:

- kernel version (`uname -r`),
- date,
- room temperature,
- benchmark app version,
- throttling notes.

## 6. Realistic expectations

- Removing `UBSAN`/`KFENCE` can reduce overhead and image size, but `KASAN`
  (HW_TAGS), `PAGE_OWNER`, and `DEBUG_LIST` intentionally stay enabled for GKI
  KMI compatibility. On devices without MTE, KASAN HW_TAGS does not instrument
  every memory access, so the performance difference is not always large.
- The biggest differences are usually in image size, build time, and memory
  usage — not necessarily in benchmark scores.
- KernelSU adds a small amount of code to the syscall path, but daily overhead
  is usually small. If it feels significant, check `CONFIG_KSU_DEBUG` (it must
  be off).
- Thermal throttling often affects scores more than kernel tweaks.

## 7. What not to do

- Compare scores taken at different temperatures or battery levels.
- Run benchmarks while charging.
- Pick the single best run and call it "the result".
- Draw performance conclusions from AnTuTu alone.
