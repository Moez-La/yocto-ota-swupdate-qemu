#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $(realpath $0))
IMAGE_DIR="/mnt/windows/yocto-ota-swupdate-qemu/build/tmp/deploy/images/qemuarm"
SWU_DIR="$SCRIPT_DIR"

echo "=== Creating SWUpdate package ==="

cp $IMAGE_DIR/gateway-image-qemuarm.rootfs.ext4 $SWU_DIR/gateway-image-qemuarm.ext4

cd $SWU_DIR

# Create .swu — sw-description must be first in the CPIO archive
for f in sw-description gateway-image-qemuarm.ext4; do
    echo $f
done | cpio -o -H newc > gateway-update-v2.0.swu

echo "=== Package created ==="
ls -lh gateway-update-v2.0.swu
