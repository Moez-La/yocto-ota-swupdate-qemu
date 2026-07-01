#!/bin/sh
MOUNTPOINT="/mnt/ubootenv"
mkdir -p $MOUNTPOINT

if mount /dev/vda1 $MOUNTPOINT 2>/dev/null; then
    CURRENT_SLOT=$(grep "^bootslot=" $MOUNTPOINT/uboot.env | cut -d'=' -f2)
    umount $MOUNTPOINT
else
    echo "ERROR: cannot mount vda1, defaulting to slot a as current"
    CURRENT_SLOT="a"
fi

if [ "$CURRENT_SLOT" = "a" ]; then
    TARGET_DEVICE="/dev/vda3"
    TARGET_SLOT="b"
else
    TARGET_DEVICE="/dev/vda2"
    TARGET_SLOT="a"
fi

echo "Current active slot: $CURRENT_SLOT"
echo "Target inactive slot: $TARGET_SLOT ($TARGET_DEVICE)"

ln -sf $TARGET_DEVICE /dev/target_slot
echo $TARGET_SLOT > /tmp/target_slot_letter

echo "preinst: /dev/target_slot -> $TARGET_DEVICE"
