SUMMARY = "Embedded Network Gateway Image with OTA support"
DESCRIPTION = "Custom image with SWUpdate for OTA A/B updates"

require recipes-core/images/core-image-minimal.bb

IMAGE_INSTALL += " \
    swupdate \
    swupdate-www \
    i2c-tools \
    ethtool \
    procps \
    iproute2 \
"

IMAGE_FEATURES += "ssh-server-dropbear"
