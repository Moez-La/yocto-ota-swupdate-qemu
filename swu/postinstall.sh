#!/bin/sh
MOUNTPOINT="/mnt/ubootenv"
mkdir -p $MOUNTPOINT

date > /tmp/postinstall_debug.log
echo "postinstall.sh STARTED" >> /tmp/postinstall_debug.log

if mount /dev/vda1 $MOUNTPOINT 2>/dev/null; then
    CURRENT_SLOT=$(grep "^bootslot=" $MOUNTPOINT/uboot.env | cut -d'=' -f2)
    umount $MOUNTPOINT
    echo "mount OK, current slot read: $CURRENT_SLOT" >> /tmp/postinstall_debug.log
else
    echo "ERROR: cannot mount vda1" >> /tmp/postinstall_debug.log
    CURRENT_SLOT="a"
fi

if [ "$CURRENT_SLOT" = "a" ]; then
    TARGET_SLOT="b"
    TARGET_DEV="/dev/vda3"
else
    TARGET_SLOT="a"
    TARGET_DEV="/dev/vda2"
fi

echo "switching from $CURRENT_SLOT to $TARGET_SLOT" >> /tmp/postinstall_debug.log

# Écrire bootslot sur vda1 FAT (lu par U-Boot)
if mount /dev/vda1 $MOUNTPOINT 2>/dev/null; then
    printf "bootcount=0\nbootlimit=3\nbootslot=%s\n" "$TARGET_SLOT" > $MOUNTPOINT/uboot.env
    umount $MOUNTPOINT
    echo "vda1 FAT updated: bootslot=$TARGET_SLOT" >> /tmp/postinstall_debug.log
fi

# Créer uboot.env libubootenv sur le slot CIBLE
SLOT_MOUNT="/mnt/target_slot"
mkdir -p $SLOT_MOUNT
if mount $TARGET_DEV $SLOT_MOUNT 2>/dev/null; then
    mkdir -p $SLOT_MOUNT/var/lib/swupdate
    printf "bootcount=0\nbootlimit=3\nbootslot=%s\n" "$TARGET_SLOT" > /tmp/env_new.txt
    mkenvimage -s 0x20000 -o $SLOT_MOUNT/var/lib/swupdate/uboot.env /tmp/env_new.txt 2>/dev/null || \
    cp /var/lib/swupdate/uboot.env $SLOT_MOUNT/var/lib/swupdate/uboot.env 2>/dev/null || true
    umount $SLOT_MOUNT
    echo "target slot $TARGET_SLOT uboot.env created" >> /tmp/postinstall_debug.log
fi

echo "postinstall.sh FINISHED" >> /tmp/postinstall_debug.log
