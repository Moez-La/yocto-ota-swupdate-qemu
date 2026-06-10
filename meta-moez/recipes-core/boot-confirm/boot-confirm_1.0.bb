SUMMARY = "Boot confirmation script — resets bootcount on successful boot"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://boot-confirm.sh \
           file://boot-confirm"

S = "${WORKDIR}"

inherit update-rc.d

INITSCRIPT_NAME = "boot-confirm"
INITSCRIPT_PARAMS = "start 99 2 3 4 5 ."

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/boot-confirm.sh ${D}${bindir}/boot-confirm.sh
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/boot-confirm ${D}${sysconfdir}/init.d/boot-confirm
}
