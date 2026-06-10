SUMMARY = "Embedded Network Gateway Monitor v1.0"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://gateway-monitor.c"

S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} gateway-monitor.c -o gateway-monitor
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 gateway-monitor ${D}${bindir}/gateway-monitor
}
