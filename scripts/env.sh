#!/usr/bin/env bash
# =============================================================================
# DarkniusX - shared environment and helper functions
# =============================================================================
# Source this file from the other scripts:
#
#   . "$(dirname "$0")/env.sh"
#
# Everything is overridable from the environment:
#
#   DARKNIUSX_HOME   build workspace (default: $HOME/darkniusx)
#   AOSP_DIR         repo checkout      (default: $DARKNIUSX_HOME/aosp)
#   ARTIFACTS_DIR    output packages    (default: $DARKNIUSX_HOME/artifacts)
#   CPUSET           taskset CPU list   (default: 0-3)
#   SKIP_MRPROPER    set to 1 for incremental builds
# =============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_DIR

DARKNIUSX_HOME="${DARKNIUSX_HOME:-$HOME/darkniusx}"
AOSP_DIR="${AOSP_DIR:-$DARKNIUSX_HOME/aosp}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$DARKNIUSX_HOME/artifacts}"
export DARKNIUSX_HOME AOSP_DIR ARTIFACTS_DIR

MANIFEST_URL="https://android.googlesource.com/kernel/manifest"
MANIFEST_BRANCH="common-android12-5.10"
FORK_URL="https://github.com/lifeats666ln/kernel_common-5.10.git"
FORK_BRANCH="android12-5.10"
FORK_COMMIT="f04d8c2a2f78a836d81d7ab0c1ab675f4ddddc9f"
KSU_VERSION="v3.4.2"
KSU_REPO="https://github.com/KernelSU-Next/KernelSU-Next.git"
KSU_SETUP_URL="https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/${KSU_VERSION}/kernel/setup.sh"
export MANIFEST_URL MANIFEST_BRANCH FORK_URL FORK_BRANCH FORK_COMMIT KSU_VERSION KSU_REPO KSU_SETUP_URL

info()  { printf '\n==> %s\n' "$*"; }
warn()  { printf '\n[WARN] %s\n' "$*" >&2; }
die()   { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "perintah '$1' tidak ditemukan. Jalankan scripts/install-deps.sh atau instal paketnya."
}

check_not_ntfs() {
	local fstype
	fstype="$(findmnt -no FSTYPE --target "$1" 2>/dev/null || true)"
	case "$fstype" in
		ntfs*|fuseblk*|vfat*|exfat*)
			die "Workspace $1 berada di filesystem $fstype. Pindahkan build ke filesystem Linux (ext4/btrfs), misalnya \$HOME/darkniusx."
			;;
	esac
}

check_host() {
	[ "$(uname -s)" = "Linux" ] || die "Build kernel ini hanya didukung di Linux."

	# Buat workspace lebih awal supaya df/findmnt punya path yang valid.
	mkdir -p "$DARKNIUSX_HOME" "$ARTIFACTS_DIR"

	local missing=()
	local c
	for c in git repo make bc bison flex cpio rsync zip unzip lz4 dtc python3 curl taskset; do
		command -v "$c" >/dev/null 2>&1 || missing+=("$c")
	done
	if [ "${#missing[@]}" -gt 0 ]; then
		die "Paket host belum lengkap: ${missing[*]}. Jalankan: bash scripts/install-deps.sh"
	fi

	check_not_ntfs "$DARKNIUSX_HOME"

	local avail_kb
	avail_kb="$(df -Pk "$DARKNIUSX_HOME" | awk 'NR==2 {print $4}')"
	if [ "${avail_kb:-0}" -lt $((80 * 1024 * 1024)) ]; then
		warn "Sisa disk di $DARKNIUSX_HOME kurang dari 80 GiB. Sync + dua varian build bisa gagal karena disk penuh."
	fi

	if [ "$(nproc)" -lt 4 ]; then
		warn "CPU hanya $(nproc) core; build akan lambat. Gunakan LTO=thin."
	fi
}

ensure_dirs() {
	mkdir -p "$DARKNIUSX_HOME" "$AOSP_DIR" "$ARTIFACTS_DIR"
}

check_tree() {
	[ -d "$AOSP_DIR/.repo" ] || die "Checkout AOSP belum ada di $AOSP_DIR. Jalankan: bash scripts/setup.sh"
	[ -x "$AOSP_DIR/build/build.sh" ] || die "build/build.sh tidak ditemukan. Sync repo mungkin belum selesai."
	[ -d "$AOSP_DIR/common" ] || die "common/ tidak ditemukan. Sync repo mungkin belum selesai."
}

repo_head() {
	git -C "$AOSP_DIR/common" rev-parse HEAD 2>/dev/null || true
}

overlay_fork() {
	info "Overlay kernel fork lifeats666ln @ ${FORK_COMMIT:0:12}"
	cd "$AOSP_DIR/common"

	if git remote get-url darkniusx >/dev/null 2>&1; then
		git remote set-url darkniusx "$FORK_URL"
	else
		git remote add darkniusx "$FORK_URL"
	fi

	# Fetch the exact pinned commit so the build still works after the fork
	# branch moves on. Fall back to the branch tip only if the server refuses
	# to serve an arbitrary SHA.
	if ! git fetch --depth=1 darkniusx "$FORK_COMMIT"; then
		warn "Fetch commit langsung gagal; mencoba branch tip ${FORK_BRANCH}"
		git fetch --depth=1 darkniusx "$FORK_BRANCH"
	fi

	local fetched
	fetched="$(git rev-parse FETCH_HEAD)"
	if [ "$fetched" != "$FORK_COMMIT" ]; then
		die "Commit ter-fetch $fetched != $FORK_COMMIT. Jika ingin update pin, ubah FORK_COMMIT di scripts/env.sh secara sengaja."
	fi

	# -f membuang perubahan tracked dari build sebelumnya (termasuk integrasi
	# KernelSU di drivers/Makefile dan drivers/Kconfig). Untracked KernelSU-Next
	# dan symlink-nya tidak dihapus; prepare_ksu akan memperbaikinya.
	git checkout -f -B darkniusx-base "$FORK_COMMIT"

	info "Kernel source: $(git log -1 --oneline)"
}

ensure_overlay() {
	check_tree
	local head
	head="$(repo_head)"
	if [ "$head" != "$FORK_COMMIT" ]; then
		warn "common/ masih di $head (bukan fork commit). Overlay otomatis..."
		overlay_fork
	else
		info "Kernel source sudah di fork commit ${FORK_COMMIT:0:12}"
	fi
}

prepare_fragments() {
	info "Menyiapkan config fragment DarkniusX"
	mkdir -p "$AOSP_DIR/.darkniusx/config" "$AOSP_DIR/.darkniusx/build"
	cp -f "$PROJECT_DIR/build/fragment.sh" "$AOSP_DIR/.darkniusx/build/fragment.sh"
	cp -f "$PROJECT_DIR/config/base.config" "$AOSP_DIR/.darkniusx/config/vanilla.config"
	cat "$PROJECT_DIR/config/base.config" "$PROJECT_DIR/config/ksu.config" \
		> "$AOSP_DIR/.darkniusx/config/ksu.config"
}

prepare_ksu() {
	info "Menyiapkan KernelSU Next ${KSU_VERSION}"
	cd "$AOSP_DIR/common"

	# Sisa ekstrak manual / clone yang rusak akan membuat setup.sh gagal.
	if [ -d KernelSU-Next ] && [ ! -d KernelSU-Next/.git ]; then
		warn "KernelSU-Next ada tetapi bukan git repo; menghapus dan clone ulang"
		rm -rf KernelSU-Next
	fi

	local need_setup=0
	[ -d KernelSU-Next ] || need_setup=1
	[ -L drivers/kernelsu ] || need_setup=1
	grep -q 'kernelsu' drivers/Makefile 2>/dev/null || need_setup=1
	grep -q 'drivers/kernelsu/Kconfig' drivers/Kconfig 2>/dev/null || need_setup=1

	if [ -d KernelSU-Next ]; then
		local tag
		tag="$(git -C KernelSU-Next describe --tags --exact-match 2>/dev/null || true)"
		[ "$tag" = "$KSU_VERSION" ] || need_setup=1
	fi

	if [ "$need_setup" -eq 1 ]; then
		[ -d KernelSU-Next ] || info "Clone KernelSU Next (sekali saja; butuh network)"
		curl -LSs "$KSU_SETUP_URL" | bash -s "$KSU_VERSION"
	else
		info "KernelSU Next ${KSU_VERSION} sudah terpasang"
	fi

	[ -L drivers/kernelsu ] || die "Symlink drivers/kernelsu tidak ada. Setup KernelSU gagal."
	grep -q 'kernelsu' drivers/Makefile || die "drivers/Makefile tidak memuat kernelsu. Setup KernelSU gagal."
	grep -q 'drivers/kernelsu/Kconfig' drivers/Kconfig || die "drivers/Kconfig tidak memuat kernelsu. Setup KernelSU gagal."

	local tag
	tag="$(git -C KernelSU-Next describe --tags --exact-match 2>/dev/null || true)"
	[ "$tag" = "$KSU_VERSION" ] || die "KernelSU Next berada di '$tag', bukan $KSU_VERSION."
}

kernel_version() {
	awk '
		/^VERSION[[:space:]]*=/    { v = $3 }
		/^PATCHLEVEL[[:space:]]*=/ { p = $3 }
		/^SUBLEVEL[[:space:]]*=/   { s = $3 }
		END { if (v && p && s) print v "." p "." s; else print "unknown" }
	' "$AOSP_DIR/common/Makefile"
}

default_cpuset() {
	if [ -n "${CPUSET:-}" ]; then
		printf '%s' "$CPUSET"
		return
	fi

	local total
	total="$(nproc)"
	if [ "$total" -ge 4 ]; then
		printf '0-3'
	else
		printf '0-%s' "$((total - 1))"
	fi
}

print_build_header() {
	local variant="$1" lto="$2" cpuset="$3"
	cat <<EOF

============================================================
 DarkniusX build
------------------------------------------------------------
 variant   : $variant
 kernel    : $(kernel_version)
 LTO       : $lto
 cpuset    : $cpuset (jobs = $(taskset -c "$cpuset" nproc 2>/dev/null || nproc))
 out dir   : $DARKNIUSX_HOME/out/$variant
 KSU       : $([ "$variant" = ksu ] && echo "$KSU_VERSION" || echo "-")
============================================================
EOF
}
