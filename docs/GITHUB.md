# Publikasi ke GitHub

## 1. Inisialisasi repository

Dari folder `DarkniusX`:

```bash
git init
git config core.filemode false   # NTFS tidak menyimpan executable bit
git add .
git commit -m "DarkniusX: GKI 5.10 build scaffold (Vanilla + KernelSU Next)"
```

Buat repository di GitHub (web atau `gh`):

```bash
gh repo create DarkniusX --public --source=. --remote=origin --push
```

Atau:

```bash
git remote add origin https://github.com/<user>/DarkniusX.git
git branch -M main
git push -u origin main
```

## 2. Yang tidak boleh di-commit

`.gitignore` sudah mengecualikan:

- `out/` — output build (puluhan GB)
- `artifacts/` — zip dan Image
- `AnyKernel3/` — template hasil clone
- `*.zip`, `*.img`, `*.log`

Jangan commit source AOSP. Source diambil ulang lewat `scripts/setup.sh`.

## 3. Rilis

Nama file yang disarankan:

```text
DarkniusX-vanilla-5.10.272-20261105.zip
DarkniusX-ksu-5.10.272-20261105.zip
DarkniusX-vanilla-5.10.272-20261105-SHA256SUMS
```

Buat release:

```bash
gh release create v1.0.0 \
  "$HOME/darkniusx/artifacts/vanilla/DarkniusX-vanilla-5.10.272-20261105.zip" \
  "$HOME/darkniusx/artifacts/vanilla/SHA256SUMS" \
  "$HOME/darkniusx/artifacts/ksu/DarkniusX-ksu-5.10.272-20261105.zip" \
  "$HOME/darkniusx/artifacts/ksu/SHA256SUMS" \
  --title "DarkniusX v1.0.0 (Linux 5.10.272)" \
  --notes-file RELEASE_NOTES.md
```

Isi release notes minimal:

- kernel version dan source commit,
- varian dan fitur,
- device/KMI yang didukung,
- Known issues,
- cara flash dan rollback (link ke `docs/FLASHING.md`),
- checksum.

## 4. GitHub Actions?

Build kernel GKI penuh **tidak realistis** di GitHub-hosted runner gratis:

- disk runner terbatas (sekitar 14 GB),
- source + prebuilt + output bisa 60 GB+,
- Full LTO butuh RAM besar,
- waktu build panjang dan mudah kena timeout.

Pilihan yang masuk akal:

1. **Build lokal + upload release** (disarankan).
2. **Self-hosted runner** di mesin sendiri, lalu workflow hanya menjalankan
   `scripts/setup.sh` dan `scripts/build.sh`.
3. CI hanya untuk lint script (`bash -n`, `shellcheck`) dan validasi config,
   bukan build penuh.

Jika memakai self-hosted runner, pastikan workspace berada di filesystem
Linux dan runner tidak di-share dengan pekerjaan lain yang bisa menghapus
`$HOME/darkniusx`.

## 5. Update rilis

1. Ubah `FORK_COMMIT` di `scripts/env.sh` (jika update kernel).
2. `bash scripts/setup.sh --no-sync`
3. `bash scripts/build.sh all thin`
4. Uji di perangkat.
5. `bash scripts/freeze.sh`
6. Commit perubahan config/script (bukan artifact).
7. Buat release baru dengan tag `vX.Y.Z`.

## 6. Keamanan

- Jangan commit file `local.properties`, token, atau kredensial.
- Jangan commit backup partisi perangkat.
- Jangan lampirkan `vmlinux` berukuran besar kecuali diperlukan untuk debug.
- Cantumkan hash SHA256 untuk setiap zip.
- Cantumkan peringatan bahwa flashing berisiko dan hanya untuk KMI yang
  didukung.
