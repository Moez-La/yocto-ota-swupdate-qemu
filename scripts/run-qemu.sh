#!/bin/bash
BUILD_DIR="/mnt/windows/yocto-ota-swupdate-qemu/build/tmp/deploy/images/qemuarm"
DISK="/mnt/windows/yocto-ota-swupdate-qemu/disk-ab.img"

# Lance ngrok en arrière-plan
ngrok http 8080 --log=stdout > /tmp/ngrok.log &
sleep 5
echo "=== ngrok URL ==="
curl -s http://localhost:4040/api/tunnels | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['tunnels'][0]['public_url'])" 2>/dev/null || cat /tmp/ngrok.log | grep "url=" | tail -1
echo "================="

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

pkill ngrok
