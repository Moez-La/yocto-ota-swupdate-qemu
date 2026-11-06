SUMMARY = "OTA Update Agent"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit update-rc.d pkgconfig

DEPENDS = "curl nlohmann-json"

SRC_URI = "file://ota-agent.cpp \
           file://ota-agent.service \
           file://ota-version \
           file://ota-agent-init \
           file://api_key"

S = "${WORKDIR}"

INITSCRIPT_NAME = "ota-agent"
INITSCRIPT_PARAMS = "start 99 2 3 4 5 ."

do_compile() {
    ${CXX} ${CXXFLAGS} ${LDFLAGS} -std=c++17 \
        -I${STAGING_INCDIR} \
        -o ota-agent ota-agent.cpp \
        -L${STAGING_LIBDIR} \
        -lcurl
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ota-agent ${D}${bindir}/ota-agent
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/ota-agent-init ${D}${sysconfdir}/init.d/ota-agent
    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/ota-version ${D}${sysconfdir}/ota-version
    install -d ${D}${sysconfdir}/ota-agent
    install -m 0600 ${WORKDIR}/api_key ${D}${sysconfdir}/ota-agent/api_key
}

FILES:${PN} += "${sysconfdir}/ota-version ${sysconfdir}/ota-agent/api_key"
