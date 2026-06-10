#!/bin/bash
set -e
SCRIPT_DIR=$(dirname $(realpath $0))
SWU_DIR="$SCRIPT_DIR"
BOOT_SCR="/tmp/boot.scr"

echo "=== Creating CORRUPTED ext4 image for rollback test ==="
MOUNT_DIR=$(mktemp -d)
IMG="$SWU_DIR/gateway-image-corrupted.ext4"

dd if=/dev/zero of=$IMG bs=1M count=50
mkfs.ext4 -L slotB-corrupted $IMG
sudo mount -o loop $IMG $MOUNT_DIR
sudo mkdir -p $MOUNT_DIR/boot
sudo cp $BOOT_SCR $MOUNT_DIR/boot/
sudo umount $MOUNT_DIR
rmdir $MOUNT_DIR

TMPDIR=$(mktemp -d)
cat > $TMPDIR/sw-description << 'SWEOF'
software =
{
    version = "2.0.0-corrupted";
    description = "CORRUPTED OTA — rollback test";
    hardware-compatibility: ["1.0", "2.0", "3.0"];
    images: (
        {
            filename = "gateway-image-corrupted.ext4";
            device = "/dev/vda3";
            type = "raw";
        }
    );
    scripts: (
        {
            filename = "postinstall.sh";
            type = "shellscript";
        }
    );
}
SWEOF

cp $SWU_DIR/postinstall.sh $TMPDIR/
cp $IMG $TMPDIR/gateway-image-corrupted.ext4

echo "=== Creating corrupted SWUpdate package ==="
cd $TMPDIR
for f in sw-description postinstall.sh gateway-image-corrupted.ext4; do
    echo $f
done | cpio -o -H newc > $SWU_DIR/gateway-update-corrupted.swu

rm -rf $TMPDIR
echo "=== Corrupted package created ==="
ls -lh $SWU_DIR/gateway-update-corrupted.swu
