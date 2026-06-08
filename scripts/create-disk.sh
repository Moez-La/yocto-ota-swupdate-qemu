#!/bin/bash
set -e
DISK_IMG="/mnt/windows/yocto-ota-swupdate-qemu/disk-ab.img"
DISK_SIZE=300  # MB

echo "=== Creating A/B partition disk image ==="
dd if=/dev/zero of=$DISK_IMG bs=1M count=$DISK_SIZE

parted -s $DISK_IMG mklabel gpt
parted -s $DISK_IMG mkpart uboot-env 1MB 2MB
parted -s $DISK_IMG mkpart slotA 2MB 152MB
parted -s $DISK_IMG mkpart slotB 152MB 302MB

echo "=== Disk created ==="
parted -s $DISK_IMG print
