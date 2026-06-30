FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://qemu_arm_virt_defconfig_fragment.cfg file://secureboot.cfg file://qemu-arm-pubkey.dtsi"

do_configure:prepend() {
    cp ${WORKDIR}/qemu-arm-pubkey.dtsi ${S}/arch/arm/dts/qemu-arm.dts
}
