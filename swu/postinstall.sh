#!/bin/sh
# Écrire bootslot=b dans /boot/uboot.env sur Slot A
mount /dev/vda2 /mnt || true
printf "bootslot=b\n" > /mnt/boot/uboot.env
umount /mnt || true
echo "bootslot set to b in /boot/uboot.env"
