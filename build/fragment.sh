# =============================================================================
# DarkniusX build config fragment
# =============================================================================
# This file is sourced by AOSP build/_setup_env.sh through:
#
#   BUILD_CONFIG_FRAGMENTS=.darkniusx/build/fragment.sh
#
# It must stay compatible with plain POSIX-ish bash; the kernel build system
# sources it with `set -a` enabled.
# =============================================================================

# The kernel source is a newer ACK fork, but its build.config.common asks for
# clang-r563880b (a 2024 toolchain) which is not part of the
# common-android12-5.10 manifest. The manifest ships clang-r416183b, the exact
# compiler used by the AOSP android12-5.10 branch this fork is based on.
# Override the path back to the toolchain that is actually in the checkout.
CLANG_PREBUILT_BIN=prebuilts-master/clang/host/linux-x86/clang-r416183b/bin

DARKNIUSX_KCONFIG_FRAGMENT="${ROOT_DIR}/.darkniusx/config/${DARKNIUSX_VARIANT}.config"

darkniusx_post_defconfig() {
	echo "========================================================"
	echo " DarkniusX: merging ${DARKNIUSX_KCONFIG_FRAGMENT}"
	echo "========================================================"

	if [ ! -f "${DARKNIUSX_KCONFIG_FRAGMENT}" ]; then
		echo "ERROR: config fragment not found: ${DARKNIUSX_KCONFIG_FRAGMENT}" >&2
		exit 1
	fi

	# Appending is intentional: later assignments win over the values that
	# gki_defconfig put in .config. olddefconfig then resolves dependencies.
	cat "${DARKNIUSX_KCONFIG_FRAGMENT}" >> "${OUT_DIR}/.config"

	# Do NOT run check_defconfig here. It compares .config against the
	# in-tree gki_defconfig and would always fail after our changes.
	(
		cd "${OUT_DIR}" &&
		make O="${OUT_DIR}" "${TOOL_ARGS[@]}" "${MAKE_ARGS[@]}" olddefconfig
	)

	# --- sanity checks -------------------------------------------------------
	if ! grep -q '^CONFIG_LOCALVERSION="-DarkniusX"' "${OUT_DIR}/.config"; then
		echo "ERROR: CONFIG_LOCALVERSION was not applied." >&2
		exit 1
	fi

	# These options are part of the GKI KMI contract (or change struct layout
	# that vendor modules are compiled against), so they MUST stay enabled.
	for opt in KASAN KASAN_HW_TAGS PAGE_OWNER DEBUG_LIST SCHEDSTATS SCHED_DEBUG; do
		if ! grep -q "^CONFIG_${opt}=y" "${OUT_DIR}/.config"; then
			echo "ERROR: CONFIG_${opt} must stay enabled for GKI compatibility." >&2
			exit 1
		fi
	done

	# These are pure debug instrumentation with no GKI KMI symbols; the
	# fragment is supposed to remove them.
	for opt in UBSAN KFENCE; do
		if grep -q "^CONFIG_${opt}=y" "${OUT_DIR}/.config"; then
			echo "ERROR: CONFIG_${opt} is still enabled; the fragment was not applied." >&2
			exit 1
		fi
	done

	# Ensure NTSYNC is enabled for both variants
	if ! grep -q '^CONFIG_NTSYNC=y' "${OUT_DIR}/.config"; then
		echo "ERROR: CONFIG_NTSYNC is not enabled." >&2
		exit 1
	fi

	if [ "${DARKNIUSX_VARIANT}" = "ksu" ]; then
		if ! grep -q '^CONFIG_KSU=y' "${OUT_DIR}/.config"; then
			echo "ERROR: CONFIG_KSU is not enabled." >&2
			echo "       Did the KernelSU Next setup script run successfully?" >&2
			exit 1
		fi
		if ! grep -q '^CONFIG_KSU_SUSFS=y' "${OUT_DIR}/.config"; then
			echo "ERROR: CONFIG_KSU_SUSFS is not enabled." >&2
			exit 1
		fi
	fi

	echo " DarkniusX: kernel config OK (${DARKNIUSX_VARIANT})"
}

POST_DEFCONFIG_CMDS=darkniusx_post_defconfig
