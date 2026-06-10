#!/bin/bash
BUILD_DIR="/mnt/windows/yocto-ota-swupdate-qemu/build/tmp/deploy/images/qemuarm"
DISK="/mnt/windows/yocto-ota-swupdate-qemu/disk-ab.img"

qemu-system-arm \
  -machine virt \
  -cpu cortex-a15 \
  -m 256 \
  -nographic \
  -bios $BUILD_DIR/u-boot.bin \
  -drive id=disk0,file=$DISK,if=none,format=raw \
  -device virtio-blk-device,drive=disk0 \
  -netdev user,id=net0,hostfwd=tcp::8080-:8080 \
  -device virtio-net-device,netdev=net0,mac=52:54:00:12:34:56
