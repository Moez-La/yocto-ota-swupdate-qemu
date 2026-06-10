#!/bin/bash
set -e
SCRIPT_DIR=$(dirname $(realpath $0))
SWU_DIR="$SCRIPT_DIR"
PRIVATE_KEY="$SCRIPT_DIR/keys/swupdate-private.pem"
TMPDIR=$(mktemp -d)

echo "=== Creating corrupted ext4 image ==="
IMG="$TMPDIR/gateway-image-qemuarm.ext4"
dd if=/dev/zero of=$IMG bs=1M count=50
mkfs.ext4 -L slotB $IMG

echo "=== Computing SHA256 hashes ==="
IMG_HASH=$(sha256sum $IMG | cut -d' ' -f1)
POST_HASH=$(sha256sum $SWU_DIR/postinstall.sh | cut -d' ' -f1)

cat > $TMPDIR/sw-description << SWDESC
software =
{
    version = "2.0.0-corrupted-signed";
    description = "CORRUPTED SIGNED OTA — rollback test";
    hardware-compatibility: ["1.0", "2.0", "3.0"];
    images: (
        {
            filename = "gateway-image-qemuarm.ext4";
            device = "/dev/vda3";
            type = "raw";
            sha256 = "$IMG_HASH";
        }
    );
    scripts: (
        {
            filename = "postinstall.sh";
            type = "shellscript";
            sha256 = "$POST_HASH";
        }
    );
}
SWDESC

echo "=== Signing ==="
openssl dgst -sha256 -sign $PRIVATE_KEY $TMPDIR/sw-description > $TMPDIR/sw-description.sig
cp $SWU_DIR/postinstall.sh $TMPDIR/postinstall.sh

echo "=== Creating package ==="
cd $TMPDIR
for f in sw-description sw-description.sig postinstall.sh gateway-image-qemuarm.ext4; do
    echo $f
done | cpio -o -H newc > $SWU_DIR/gateway-update-corrupted-signed.swu

rm -rf $TMPDIR
echo "=== Done ==="
ls -lh $SWU_DIR/gateway-update-corrupted-signed.swu
