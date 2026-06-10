FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://swupdate-public.pem \
            file://swupdate-runtime.cfg \
            file://swupdate-signing.cfg"

do_install:append() {
    install -d ${D}${sysconfdir}/swupdate
    install -m 0644 ${WORKDIR}/swupdate-public.pem ${D}${sysconfdir}/swupdate/swupdate-public.pem
    install -m 0644 ${WORKDIR}/swupdate-runtime.cfg ${D}${sysconfdir}/swupdate/swupdate.cfg
}
