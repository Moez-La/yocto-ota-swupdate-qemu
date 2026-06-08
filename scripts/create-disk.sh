#!/bin/bash
# Create a disk image with A/B partitions for OTA testing

set -e

DISK_IMG="disk-ab.img"
DISK_SIZE=128  # MB

echo "=== Creating A/B partition disk image ==="

# Create empty disk image
dd if=/dev/zero of=$DISK_IMG bs=1M count=$DISK_SIZE

# Partition it: 1MB uboot-env, 60MB Slot A, 60MB Slot B
parted -s $DISK_IMG mklabel gpt
parted -s $DISK_IMG mkpart uboot-env 1MB 2MB
parted -s $DISK_IMG mkpart slotA 2MB 62MB
parted -s $DISK_IMG mkpart slotB 62MB 122MB

echo "=== Disk created ==="
parted -s $DISK_IMG print
