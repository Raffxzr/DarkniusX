### AnyKernel3 Ramdisk Mod Script
## DarkniusX kernel flasher
##
## Universal for any device running GKI android12-5.10 (KMI generation 9).
## The installer reads the current boot kernel and aborts unless it reports
## "-android12-9-", so the package is not tied to one codename.
##
## It ONLY replaces the kernel inside the existing boot partition. It does not
## touch vendor_boot, vendor_dlkm, dtbo, or the separate GPU overclock module.
##
## The packaging script fills in kernel.string.

properties() { '
kernel.string=DarkniusX
do.devicecheck=0
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# Import functions/variables and setup patching (DO NOT REMOVE)
. tools/ak3-core.sh;

# split_boot: unpack boot but keep the existing ramdisk bytes untouched.
# flash_boot: repack and write the new boot image.
split_boot;

# Safety guard: this kernel is only for GKI android12-5.10 (KMI generation 9).
# The package is universal across codenames, so the boot image itself is the
# source of truth. Refuse to continue if the kernel is not in boot or if the
# current kernel reports another KMI.
if [ ! -f "$SPLITIMG/kernel" ]; then
	ui_print " ";
	ui_print "*** DarkniusX: no kernel found in the boot partition ***";
	abort "This package requires the kernel to live in the boot partition.";
fi;

# Accept a stock KMI 9 kernel (-android12-9-) or an already-installed
# DarkniusX build (-DarkniusX) so updates and Vanilla <-> KSU switches work.
if ! strings "$SPLITIMG/kernel" | grep -qE -- '-android12-9-|-DarkniusX'; then
	ui_print " ";
	ui_print "*** DarkniusX: incompatible kernel detected ***";
	ui_print "This package requires android12-5.10 (KMI 9).";
	ui_print "Your current boot kernel is not -android12-9-.";
	abort "Installation aborted to protect your device.";
fi;

flash_boot;
