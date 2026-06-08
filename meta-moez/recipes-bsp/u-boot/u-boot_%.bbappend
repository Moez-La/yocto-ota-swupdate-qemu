FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://qemu_arm_virt_defconfig_fragment.cfg"
