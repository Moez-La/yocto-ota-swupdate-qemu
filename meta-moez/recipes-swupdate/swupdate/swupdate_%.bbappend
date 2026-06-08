SWUPDATE_ARGS = "-H qemuarm:1.0 -m"
do_install:append() {
    echo "/dev/vda1 0x0000 0x100000" > ${D}/etc/fw_env.config
}
