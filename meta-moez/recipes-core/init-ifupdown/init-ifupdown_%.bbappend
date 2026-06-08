do_install:append() {
    echo "" >> ${D}${sysconfdir}/network/interfaces
    echo "auto eth0" >> ${D}${sysconfdir}/network/interfaces
    echo "iface eth0 inet dhcp" >> ${D}${sysconfdir}/network/interfaces
}
