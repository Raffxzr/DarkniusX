#!/usr/bin/env bash
# =============================================================================
# DarkniusX - freeze exact revisions for reproducible builds
# =============================================================================
# Usage: bash scripts/freeze.sh
#
# Outputs into $ARTIFACTS_DIR/freeze-<timestamp>/:
#   manifest.xml      pinned repo manifest
#   versions.txt      kernel / fork / KernelSU / clang revisions
#   *.config          exact config fragments used
# =============================================================================

set -euo pipefail

. "$(dirname "$0")/env.sh"

check_tree
ensure_overlay
prepare_fragments

STAMP="$(date -u '+%Y%m%d-%H%M%S')"
OUT="$ARTIFACTS_DIR/freeze-$STAMP"
mkdir -p "$OUT"

info "Menyimpan manifest terkunci"
(
	cd "$AOSP_DIR"
	repo manifest -r -o "$OUT/manifest.xml"
)

CLANG_BIN="$AOSP_DIR/prebuilts-master/clang/host/linux-x86/clang-r416183b/bin/clang"
CLANG_VER="unknown"
if [ -x "$CLANG_BIN" ]; then
	CLANG_VER="$("$CLANG_BIN" --version | head -n1)"
fi

KSU_TAG="-"
if [ -d "$AOSP_DIR/common/KernelSU-Next/.git" ]; then
	KSU_TAG="$(git -C "$AOSP_DIR/common/KernelSU-Next" describe --tags --always 2>/dev/null || echo unknown)"
fi

cat > "$OUT/versions.txt" <<EOF
DarkniusX freeze
================
date          : $(date -u '+%Y-%m-%d %H:%M UTC')
kernel        : $(kernel_version)
common HEAD   : $(git -C "$AOSP_DIR/common" rev-parse HEAD)
common subject: $(git -C "$AOSP_DIR/common" log -1 --format=%s)
fork URL      : $FORK_URL
fork branch   : $FORK_BRANCH
KernelSU      : $KSU_TAG
clang         : $CLANG_VER
host          : $(uname -srm)
EOF

cp -f "$PROJECT_DIR/config/base.config" "$OUT/base.config"
cp -f "$PROJECT_DIR/config/ksu.config" "$OUT/ksu.config"
cp -f "$PROJECT_DIR/build/fragment.sh" "$OUT/build-fragment.sh"

info "Freeze selesai: $OUT"
cat "$OUT/versions.txt"
