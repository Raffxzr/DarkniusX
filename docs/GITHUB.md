# Publishing to GitHub

## 1. Initialize the repository

From the `DarkniusX` folder:

```bash
git init
git config core.filemode false   # NTFS does not preserve executable bits
git add .
git commit -m "DarkniusX: GKI 5.10 build scaffold (Vanilla + KernelSU Next)"
```

Create the repository on GitHub (web or `gh`):

```bash
gh repo create DarkniusX --public --source=. --remote=origin --push
```

Or:

```bash
git remote add origin https://github.com/Raffxzr/DarkniusX.git
git branch -M main
git push -u origin main
```

Public repository: <https://github.com/Raffxzr/DarkniusX>.

## 2. What must not be committed

`.gitignore` already excludes:

- `out/` — build output (tens of GB)
- `artifacts/` — zips and images
- `AnyKernel3/` — cloned template
- `*.zip`, `*.img`, `*.log`

Do not commit the AOSP source tree. It is fetched again by `scripts/setup.sh`.

## 3. Release

Suggested asset names:

```text
DarkniusX-vanilla-5.10.272-20261105.zip
DarkniusX-ksu-5.10.272-20261105.zip
SHA256SUMS
BUILD_INFO-vanilla.txt
BUILD_INFO-ksu.txt
```

Create the release (use `--prerelease` until it has been tested on a device):

```bash
gh release create v1.0.0 \
  "$HOME/darkniusx/artifacts/vanilla/DarkniusX-vanilla-5.10.272-20261105.zip" \
  "$HOME/darkniusx/artifacts/ksu/DarkniusX-ksu-5.10.272-20261105.zip" \
  "$HOME/darkniusx/artifacts/vanilla/BUILD_INFO.txt#BUILD_INFO-vanilla.txt" \
  "$HOME/darkniusx/artifacts/ksu/BUILD_INFO.txt#BUILD_INFO-ksu.txt" \
  --title "DarkniusX v1.0.0 (Linux 5.10.272)" \
  --notes-file RELEASE_NOTES.md \
  --prerelease
```

`SHA256SUMS`, configs, ABI, and the manifest can be added as extra assets after
the release is created.

Release notes should include at least:

- kernel version and source commit,
- variants and features,
- supported KMI (universal `android12-5.10` / KMI 9, no codename),
- known issues,
- flashing and rollback instructions (link to `docs/FLASHING.md`),
- checksums.

## 4. GitHub Actions?

A full GKI kernel build is **not realistic** on free GitHub-hosted runners:

- runner disk is limited (around 14 GB),
- source + prebuilts + output can exceed 60 GB,
- Full LTO needs a lot of RAM,
- builds take a long time and are prone to timeouts.

Reasonable options:

1. **Build locally + upload the release** (recommended).
2. **Self-hosted runner** on your own machine, with a workflow that only runs
   `scripts/setup.sh` and `scripts/build.sh`.
3. CI only for script linting (`bash -n`, `shellcheck`) and config validation,
   not a full build.

If you use a self-hosted runner, make sure the workspace is on a Linux
filesystem and the runner is not shared with other jobs that might delete
`$HOME/darkniusx`.

## 5. Release updates

1. Change `FORK_COMMIT` in `scripts/env.sh` (when updating the kernel).
2. `bash scripts/setup.sh --no-sync`
3. `bash scripts/build.sh all thin`
4. Test on a device.
5. `bash scripts/freeze.sh`
6. Commit config/script changes (not artifacts).
7. Create a new release tagged `vX.Y.Z`.

## 6. Security

- Do not commit `local.properties`, tokens, or credentials.
- Do not commit device partition backups.
- Do not attach a large `vmlinux` unless it is needed for debugging.
- Include a SHA256 hash for every zip.
- Include a warning that flashing is risky and only supported for the stated
  KMI.
