fatload virtio 0:1 0x44000000 uboot.env
env import -t 0x44000000 $filesize

if test "${bootslot}" = "b"; then
  echo "Slot B - bootcount=${bootcount} / bootlimit=${bootlimit}"
  if test ${bootcount} -ge ${bootlimit}; then
    echo "ROLLBACK: reverting to Slot A"
    setenv bootslot a
    setenv bootcount 0
  else
    setexpr bootcount ${bootcount} + 1
  fi
else
  echo "Slot A - normal boot"
fi

env export -t 0x44000000 bootslot bootcount bootlimit
fatwrite virtio 0:1 0x44000000 uboot.env ${filesize}

if test "${bootslot}" = "a"; then
  echo "Booting from Slot a (partition 2) - signed FIT"
  setenv bootargs "root=/dev/vda2 rw console=ttyAMA0 panic=5"
  ext4load virtio 0:2 0x44000000 /boot/kernel.itb
  fdt addr $fdtcontroladdr
  bootm 0x44000000#conf-1 - $fdtcontroladdr
else
  echo "Booting from Slot b (partition 3) - signed FIT"
  setenv bootargs "root=/dev/vda3 rw console=ttyAMA0 panic=5"
  ext4load virtio 0:3 0x44000000 /boot/kernel.itb
  fdt addr $fdtcontroladdr
  bootm 0x44000000#conf-1 - $fdtcontroladdr
fi
