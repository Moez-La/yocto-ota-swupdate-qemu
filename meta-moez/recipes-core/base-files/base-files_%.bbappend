do_install:append() {
    echo "qemuarm:1.0" > ${D}${sysconfdir}/hwrevision
    install -d ${D}${sysconfdir}/swupdate/conf.d
    echo 'SWUPDATE_ARGS="-v -H qemuarm:1.0 -f /etc/swupdate/swupdate.cfg ${SWUPDATE_EXTRA_ARGS}"' > ${D}${sysconfdir}/swupdate/conf.d/09_args.conf
    echo 'SWUPDATE_WEBSERVER_ARGS="-r /www -p 8080"' >> ${D}${sysconfdir}/swupdate/conf.d/09_args.conf
}
