#!/bin/bash
set -e
SCRIPT_DIR=$(dirname $(realpath $0))
BUILD_DIR="/mnt/windows/yocto-ota-swupdate-qemu/build/tmp/deploy/images/qemuarm"
SWU_DIR="$SCRIPT_DIR"
BOOT_SCR="/tmp/boot.scr"

echo "=== Creating full ext4 image with rootfs + kernel + boot.scr ==="
MOUNT_DIR=$(mktemp -d)
IMG="$SWU_DIR/gateway-image-qemuarm.ext4"

# Copie directement depuis l'image ext4 Yocto
cp $BUILD_DIR/gateway-image-qemuarm.rootfs.ext4 $IMG

# Monte et ajoute kernel + boot.scr
sudo mount -o loop $IMG $MOUNT_DIR
sudo cp $BUILD_DIR/zImage $MOUNT_DIR/boot/
sudo cp $BOOT_SCR $MOUNT_DIR/boot/
sudo umount $MOUNT_DIR
rmdir $MOUNT_DIR

echo "=== Creating SWUpdate package ==="
cd $SWU_DIR
for f in sw-description postinstall.sh gateway-image-qemuarm.ext4; do
    echo $f
done | cpio -o -H newc > gateway-update-v2.0.swu

echo "=== Package created ==="
ls -lh gateway-update-v2.0.swu
