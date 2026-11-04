#!/usr/bin/env bash
# =============================================================================
# DarkniusX - build kernel
# =============================================================================
# Usage:
#   bash scripts/build.sh vanilla [thin|full]
#   bash scripts/build.sh ksu     [thin|full]
#   bash scripts/build.sh all     [thin|full]
#
# Environment:
#   CPUSET=0-5        pakai 6 core (default 0-3 = 4 core, aman untuk 15 GiB RAM)
#   SKIP_MRPROPER=1   incremental build (tidak menghapus out dir)
#   LTO=thin|full     default thin
# =============================================================================

set -euo pipefail

. "$(dirname "$0")/env.sh"

TARGET="${1:-}"
LTO="${2:-${LTO:-thin}}"

case "$TARGET" in
	vanilla|ksu|all) ;;
	*) die "Usage: bash scripts/build.sh <vanilla|ksu|all> [thin|full]" ;;
esac

case "$LTO" in
	thin|full|none) ;;
	*) die "LTO harus thin, full, atau none" ;;
esac

check_host
ensure_overlay

run_build() {
	local variant="$1"
	local out_dir="$DARKNIUSX_HOME/out/$variant"
	local dist_dir="$out_dir/dist"
	local cpuset
	cpuset="$(default_cpuset)"

	prepare_fragments

	if [ "$variant" = "ksu" ]; then
		prepare_ksu
	fi

	if [ "$LTO" = "full" ]; then
		local avail_gb
		avail_gb="$(free -g | awk '/^Mem:/ {print $7}')"
		if [ "${avail_gb:-0}" -lt 12 ]; then
			warn "LTO=full dengan RAM tersedia ${avail_gb} GiB bisa OOM. Pertimbangkan LTO=thin atau CPUSET=0-1."
		fi
	fi

	mkdir -p "$out_dir" "$DARKNIUSX_HOME/logs" "$ARTIFACTS_DIR"
	local log="$DARKNIUSX_HOME/logs/build-$variant-$(date +%Y%m%d-%H%M%S).log"

	print_build_header "$variant" "$LTO" "$cpuset"
	info "Log: $log"

	cd "$AOSP_DIR"
	# Catatan: build.sh menimpa MAKEFLAGS dengan -j$(nproc). taskset membatasi
	# jumlah CPU yang terlihat oleh nproc, sehingga jumlah job ikut turun.
	(
		export BUILD_CONFIG="common/build.config.gki.aarch64"
		export BUILD_CONFIG_FRAGMENTS=".darkniusx/build/fragment.sh"
		export DARKNIUSX_VARIANT="$variant"
		export OUT_DIR="$out_dir"
		export DIST_DIR="$dist_dir"
		export LTO
		export SKIP_MRPROPER="${SKIP_MRPROPER:-0}"
		taskset -c "$cpuset" ./build/build.sh
	) 2>&1 | tee "$log"

	[ -f "$dist_dir/Image" ] || die "Build selesai tanpa dist/Image. Cek log: $log"
	[ -f "$dist_dir/Image.lz4" ] || die "Build selesai tanpa dist/Image.lz4. Cek log: $log"

	info "Build $variant selesai"
	bash "$PROJECT_DIR/scripts/package.sh" "$variant"
}

if [ "$TARGET" = "all" ]; then
	run_build vanilla
	run_build ksu
else
	run_build "$TARGET"
fi

info "Semua build selesai."
