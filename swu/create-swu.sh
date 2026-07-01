#!/bin/bash
set -e
SCRIPT_DIR=$(dirname $(realpath $0))
BUILD_DIR="/mnt/windows/yocto-ota-swupdate-qemu/build/tmp/deploy/images/qemuarm"
SWU_DIR="$SCRIPT_DIR"
BOOT_SCR="/tmp/boot.scr"
KERNEL_ITB="/mnt/windows/yocto-ota-swupdate-qemu/secureboot/fit/kernel.itb"
PRIVATE_KEY="$SCRIPT_DIR/keys/swupdate-private.pem"

echo "=== Creating full ext4 image with rootfs + kernel + boot.scr ==="
MOUNT_DIR=$(mktemp -d)
IMG="$SWU_DIR/gateway-image-qemuarm.ext4"
cp $BUILD_DIR/gateway-image-qemuarm.rootfs.ext4 $IMG
sudo mount -o loop $IMG $MOUNT_DIR
sudo cp $BUILD_DIR/zImage $MOUNT_DIR/boot/
sudo cp $BOOT_SCR $MOUNT_DIR/boot/
if [ -f "$KERNEL_ITB" ]; then
    sudo cp $KERNEL_ITB $MOUNT_DIR/boot/
fi
sudo umount $MOUNT_DIR
rmdir $MOUNT_DIR

echo "=== Computing SHA256 hashes ==="
IMG_HASH=$(sha256sum $IMG | cut -d' ' -f1)
PREINST_HASH=$(sha256sum $SWU_DIR/preinst.sh | cut -d' ' -f1)
POST_HASH=$(sha256sum $SWU_DIR/postinstall.sh | cut -d' ' -f1)

echo "Image hash    : $IMG_HASH"
echo "Preinst hash  : $PREINST_HASH"
echo "Postinst hash : $POST_HASH"

echo "=== Generating sw-description ==="
cat > $SWU_DIR/sw-description << SWDESC
software =
{
    version = "2.0.0";
    description = "Gateway Monitor OTA update - dynamic slot targeting";
    hardware-compatibility: ["1.0", "2.0", "3.0"];
    scripts: (
        {
            filename = "preinst.sh";
            type = "preinstall";
            sha256 = "$PREINST_HASH";
        },
        {
            filename = "postinstall.sh";
            type = "postinstall";
            sha256 = "$POST_HASH";
        }
    );
    images: (
        {
            filename = "gateway-image-qemuarm.ext4";
            device = "/dev/target_slot";
            type = "raw";
            sha256 = "$IMG_HASH";
        }
    );
}
SWDESC

echo "=== Signing sw-description ==="
openssl dgst -sha256 -sign $PRIVATE_KEY $SWU_DIR/sw-description > $SWU_DIR/sw-description.sig
echo "sw-description signed"

echo "=== Creating signed SWUpdate package ==="
cd $SWU_DIR
for f in sw-description sw-description.sig preinst.sh postinstall.sh gateway-image-qemuarm.ext4; do
    echo $f
done | cpio -o -H newc > gateway-update-v2.0.swu

echo "=== Package created ==="
ls -lh gateway-update-v2.0.swu
