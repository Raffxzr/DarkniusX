#!/usr/bin/env bash
# =============================================================================
# DarkniusX - host dependency installer
# =============================================================================
# Supports Arch/CachyOS (host) and Debian/Ubuntu (distrobox).
# Run with: bash scripts/install-deps.sh
# =============================================================================

set -euo pipefail

. "$(dirname "$0")/env.sh"

if [ -f /etc/arch-release ] || grep -qi '^ID=cachyos' /etc/os-release 2>/dev/null; then
	info "Arch/CachyOS terdeteksi"
	sudo pacman -S --needed --noconfirm \
		base-devel git curl wget python python-pip openssl bc cpio flex bison \
		ncurses libelf elfutils rsync zip unzip ccache lz4 zstd jq dtc repo \
		android-tools
elif [ -f /etc/debian_version ]; then
	info "Debian/Ubuntu terdeteksi"
	sudo apt-get update
	sudo apt-get install -y \
		build-essential git curl wget python3 python3-pip bc bison flex cpio \
		libelf-dev libssl-dev libncurses-dev rsync zip unzip ccache lz4 zstd \
		jq device-tree-compiler android-tools-adb android-tools-fastboot
	if ! command -v repo >/dev/null 2>&1; then
		info "repo tidak ada di apt; memasang launcher ke ~/.local/bin"
		mkdir -p "$HOME/.local/bin"
		curl -LSs https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/.local/bin/repo"
		chmod a+x "$HOME/.local/bin/repo"
		case ":$PATH:" in
			*":$HOME/.local/bin:"*) ;;
			*) warn "Tambahkan \$HOME/.local/bin ke PATH." ;;
		esac
	fi
else
	die "Distro tidak dikenali. Instal manual: git repo make bc bison flex cpio rsync zip unzip lz4 dtc python3 curl."
fi

info "Dependensi selesai. Cek dengan: bash scripts/setup.sh --check"
