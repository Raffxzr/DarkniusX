#!/usr/bin/env bash
# =============================================================================
# DarkniusX - first-time / update source setup
# =============================================================================
# Usage:
#   bash scripts/setup.sh            # check host, repo sync, overlay fork
#   bash scripts/setup.sh --no-sync  # overlay + prepare only (source already exists)
#   bash scripts/setup.sh --check    # check host and source status, no sync
# =============================================================================

set -euo pipefail

. "$(dirname "$0")/env.sh"

MODE="sync"
case "${1:-}" in
	--no-sync) MODE="no-sync" ;;
	--check)   MODE="check" ;;
	"")        ;;
	*)         die "Unknown argument: $1" ;;
esac

check_host
ensure_dirs
check_not_ntfs "$AOSP_DIR"

info "Workspace : $DARKNIUSX_HOME"
info "AOSP      : $AOSP_DIR"
info "Artifacts : $ARTIFACTS_DIR"

if [ "$MODE" = "check" ]; then
	if [ -d "$AOSP_DIR/.repo" ]; then
		info "AOSP checkout found"
		git -C "$AOSP_DIR/common" log -1 --oneline 2>/dev/null || true
	else
		warn "AOSP checkout is missing"
	fi
	exit 0
fi

if [ "$MODE" = "sync" ]; then
	cd "$AOSP_DIR"

	if [ ! -d .repo ]; then
		info "repo init (shallow, branch $MANIFEST_BRANCH)"
		repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --depth=1
	else
		info "repo is already initialized; continuing with sync"
	fi

	info "repo sync (this downloads several GB; be patient)"
	repo sync -c -j"${SYNC_JOBS:-8}" --no-tags --no-clone-bundle --force-sync
fi

check_tree
overlay_fork
prepare_fragments

info "Done. Next steps:"
cat <<EOF

  bash scripts/build.sh vanilla thin
  bash scripts/build.sh ksu thin

 or both:

  bash scripts/build.sh all thin

Zip outputs are in:
  $ARTIFACTS_DIR/vanilla/
  $ARTIFACTS_DIR/ksu/

EOF
