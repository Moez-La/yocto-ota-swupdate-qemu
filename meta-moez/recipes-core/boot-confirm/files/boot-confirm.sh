#!/bin/sh
MOUNTPOINT="/mnt/ubootenv"
mkdir -p $MOUNTPOINT
if mount /dev/vda1 $MOUNTPOINT 2>/dev/null; then
    if [ -f "$MOUNTPOINT/uboot.env" ]; then
        BOOTSLOT=$(grep "bootslot" $MOUNTPOINT/uboot.env | cut -d= -f2 | tr -d '\n\r ')
        if [ "$BOOTSLOT" = "b" ]; then
            printf "bootcount=0\nbootlimit=3\nbootslot=b\n" > $MOUNTPOINT/uboot.env
            echo "boot-confirm: bootcount reset to 0 on Slot B"
        fi
    fi
    umount $MOUNTPOINT
fi
