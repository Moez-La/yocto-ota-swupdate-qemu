#!/bin/sh
MOUNTPOINT="/mnt/ubootenv"
mkdir -p $MOUNTPOINT
if mount /dev/vda1 $MOUNTPOINT 2>/dev/null; then
    printf "bootcount=0\nbootlimit=3\nbootslot=b\n" > $MOUNTPOINT/uboot.env
    umount $MOUNTPOINT
    echo "bootslot set to b in vda1 FAT"
else
    echo "ERROR: cannot mount vda1"
fi
