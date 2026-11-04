#!/usr/bin/env bash
# =============================================================================
# DarkniusX - first-time / update source setup
# =============================================================================
# Usage:
#   bash scripts/setup.sh            # check host, repo sync, overlay fork
#   bash scripts/setup.sh --no-sync  # overlay + prepare only (source sudah ada)
#   bash scripts/setup.sh --check    # cek host dan status source, tanpa sync
# =============================================================================

set -euo pipefail

. "$(dirname "$0")/env.sh"

MODE="sync"
case "${1:-}" in
	--no-sync) MODE="no-sync" ;;
	--check)   MODE="check" ;;
	"")        ;;
	*)         die "Argumen tidak dikenal: $1" ;;
esac

check_host
ensure_dirs
check_not_ntfs "$AOSP_DIR"

info "Workspace : $DARKNIUSX_HOME"
info "AOSP      : $AOSP_DIR"
info "Artifacts : $ARTIFACTS_DIR"

if [ "$MODE" = "check" ]; then
	if [ -d "$AOSP_DIR/.repo" ]; then
		info "Checkout AOSP ditemukan"
		git -C "$AOSP_DIR/common" log -1 --oneline 2>/dev/null || true
	else
		warn "Checkout AOSP belum ada"
	fi
	exit 0
fi

if [ "$MODE" = "sync" ]; then
	cd "$AOSP_DIR"

	if [ ! -d .repo ]; then
		info "repo init (shallow, branch $MANIFEST_BRANCH)"
		repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --depth=1
	else
		info "repo sudah diinisialisasi; lanjut sync"
	fi

	info "repo sync (ini mengunduh beberapa GB; sabar)"
	repo sync -c -j"${SYNC_JOBS:-8}" --no-tags --no-clone-bundle --force-sync
fi

check_tree
overlay_fork
prepare_fragments

info "Selesai. Langkah berikutnya:"
cat <<EOF

  bash scripts/build.sh vanilla thin
  bash scripts/build.sh ksu thin

 atau keduanya:

  bash scripts/build.sh all thin

Hasil zip ada di:
  $ARTIFACTS_DIR/vanilla/
  $ARTIFACTS_DIR/ksu/

EOF
