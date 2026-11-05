#!/usr/bin/env bash
# =============================================================================
# DarkniusX - package build artifacts + AnyKernel3 zip
# =============================================================================
# Usage: bash scripts/package.sh <vanilla|ksu>
#
# Env:
#   INCLUDE_VMLINUX=1      ikutkan vmlinux (besar, hanya untuk debugging)
#
# Paket bersifat universal untuk perangkat GKI android12-5.10 (KMI 9).
# Tidak ada device/codename check; anykernel.sh memverifikasi kernel di
# partisi boot dan membatalkan flash jika bukan -android12-9-.
# =============================================================================

set -euo pipefail

. "$(dirname "$0")/env.sh"

VARIANT="${1:-}"
case "$VARIANT" in
	vanilla|ksu) ;;
	*) die "Usage: bash scripts/package.sh <vanilla|ksu>" ;;
esac

DIST_DIR="$DARKNIUSX_HOME/out/$VARIANT/dist"
OUT_DIR="$ARTIFACTS_DIR/$VARIANT"
AK3_DIR="$DARKNIUSX_HOME/AnyKernel3"
AK3_COMMIT="41f04bdb4ee30a44e429c2c1131d5e8bb32b15f1"

[ -f "$DIST_DIR/Image" ] || die "dist/Image tidak ada: $DIST_DIR"
[ -f "$DIST_DIR/Image.lz4" ] || die "dist/Image.lz4 tidak ada: $DIST_DIR"

KVER="$(kernel_version)"
SRC_COMMIT="$(git -C "$AOSP_DIR/common" rev-parse HEAD 2>/dev/null || echo unknown)"
SRC_SHORT="$(printf '%s' "$SRC_COMMIT" | cut -c1-12)"
BUILD_DATE="$(date -u '+%Y-%m-%d %H:%M UTC')"
CONFIG_FILE="$DARKNIUSX_HOME/out/$VARIANT/common/.config"

LTO_MODE="unknown"
if [ -f "$CONFIG_FILE" ]; then
	if grep -q '^CONFIG_LTO_CLANG_FULL=y' "$CONFIG_FILE"; then
		LTO_MODE="full"
	elif grep -q '^CONFIG_LTO_CLANG_THIN=y' "$CONFIG_FILE"; then
		LTO_MODE="thin"
	elif grep -q '^CONFIG_LTO_NONE=y' "$CONFIG_FILE"; then
		LTO_MODE="none"
	fi
fi

info "Packaging $VARIANT (kernel $KVER, LTO $LTO_MODE)"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

cp -f "$DIST_DIR/Image" "$OUT_DIR/Image"
cp -f "$DIST_DIR/Image.lz4" "$OUT_DIR/Image.lz4"
if [ -f "$DIST_DIR/System.map" ]; then
	cp -f "$DIST_DIR/System.map" "$OUT_DIR/System.map"
fi
if [ -f "$DIST_DIR/vmlinux.symvers" ]; then
	cp -f "$DIST_DIR/vmlinux.symvers" "$OUT_DIR/vmlinux.symvers"
fi
if [ -f "$DIST_DIR/abi.xml" ]; then
	cp -f "$DIST_DIR/abi.xml" "$OUT_DIR/abi.xml"
fi
if [ -f "$CONFIG_FILE" ]; then
	cp -f "$CONFIG_FILE" "$OUT_DIR/config"
fi
if [ "${INCLUDE_VMLINUX:-0}" = "1" ] && [ -f "$DIST_DIR/vmlinux" ]; then
	cp -f "$DIST_DIR/vmlinux" "$OUT_DIR/vmlinux"
fi

cat > "$OUT_DIR/BUILD_INFO.txt" <<EOF
DarkniusX kernel build
======================
variant      : $VARIANT
kernel       : $KVER
source       : lifeats666ln/kernel_common-5.10 @ $SRC_COMMIT
KernelSU     : $([ "$VARIANT" = "ksu" ] && echo "$KSU_VERSION" || echo "-")
localversion : -DarkniusX
LTO          : $LTO_MODE
coverage     : universal GKI android12-5.10 (KMI 9), no codename check
built        : $BUILD_DATE
host         : $(uname -srm)
build user   : ${USER:-unknown}
EOF

# -----------------------------------------------------------------------------
# AnyKernel3 zip
# -----------------------------------------------------------------------------
info "Menyiapkan AnyKernel3"
if [ ! -d "$AK3_DIR/.git" ]; then
	rm -rf "$AK3_DIR"
	git clone https://github.com/osm0sis/AnyKernel3.git "$AK3_DIR"
fi
git -C "$AK3_DIR" fetch --tags --force --quiet
git -C "$AK3_DIR" checkout -f "$AK3_COMMIT" >/dev/null 2>&1 || die "Tidak bisa checkout AnyKernel3 $AK3_COMMIT"

TMP_DIR="$(mktemp -d "$DARKNIUSX_HOME/ak3-XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

cp -a "$AK3_DIR"/. "$TMP_DIR"/
rm -rf "$TMP_DIR/.git"
cp -f "$PROJECT_DIR/flasher/anykernel.sh" "$TMP_DIR/anykernel.sh"
cp -f "$OUT_DIR/Image" "$TMP_DIR/Image"

sed -i "s|^kernel.string=.*|kernel.string=DarkniusX ${VARIANT} ${KVER} (${LTO_MODE} LTO, universal KMI 9)|" "$TMP_DIR/anykernel.sh"
info "Mode universal: tanpa device/codename check (guard: -android12-9-)"

ZIP_NAME="DarkniusX-${VARIANT}-${KVER}-$(date -u '+%Y%m%d').zip"
(
	cd "$TMP_DIR"
	zip -r9 "$OUT_DIR/$ZIP_NAME" . -x '.git/*' >/dev/null
)

(
	cd "$OUT_DIR"
	find . -maxdepth 1 -type f ! -name SHA256SUMS -printf '%f\n' | sort | xargs sha256sum > SHA256SUMS
)

info "Selesai: $OUT_DIR/$ZIP_NAME"
echo
cat "$OUT_DIR/BUILD_INFO.txt"
echo
echo "SHA256:"
grep " $ZIP_NAME\$" "$OUT_DIR/SHA256SUMS" || true
