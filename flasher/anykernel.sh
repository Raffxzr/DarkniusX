### AnyKernel3 Ramdisk Mod Script
## DarkniusX kernel flasher
##
## This template ONLY replaces the kernel inside the existing boot partition.
## It does not touch vendor_boot, vendor_dlkm, dtbo, or the GPU overclock module.
##
## The packaging script fills in kernel.string and (optionally) device.name1.

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
flash_boot;
