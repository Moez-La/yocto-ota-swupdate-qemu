# yocto-ota-swupdate-qemu

![Status](https://img.shields.io/badge/status-phase%204%20in%20progress-orange)
![Platform](https://img.shields.io/badge/platform-QEMU%20ARM-blue)
![Build](https://img.shields.io/badge/build%20system-Yocto%20Scarthgap-green)
![SWUpdate](https://img.shields.io/badge/SWUpdate-v2026.05-brightgreen)
![CI](https://github.com/Moez-La/yocto-ota-swupdate-qemu/actions/workflows/build.yml/badge.svg)

Embedded Linux image built with **Yocto Project (Scarthgap)** for QEMU ARM — featuring a complete OTA (Over-The-Air) update pipeline with **SWUpdate** and **A/B partition scheme** with automatic rollback via **U-Boot**.

---

## Overview

This project demonstrates a production-ready embedded Linux update mechanism — the kind used in industrial equipment, automotive systems, and defense electronics deployed in the field.

A custom **Network Gateway Monitor** application (written in C) runs on the embedded system and displays real-time network statistics read directly from the Linux kernel via `/proc`. The application exists in two versions to demonstrate the OTA update:

- **v1.0** — Basic monitoring: IP address, RX/TX bytes, status
- **v2.0** — Enhanced monitoring: adds CPU load, RAM usage, packet counter, and firewall status

The system receives the v2.0 update remotely via HTTP, SWUpdate installs it safely, and the new features become immediately visible — demonstrating a real OTA update on an ARMv7 embedded system.

---

## Architecture

```
+------------------------------------------------------------------+
|                         QEMU ARM (qemuarm)                       |
|                                                                  |
|  +----------+  +----------------+  +----------------+            |
|  |   vda1   |  |     vda2       |  |     vda3       |            |
|  | FAT 1MB  |  |  Slot A 150MB  |  |  Slot B 150MB  |            |
|  |uboot.env |  | Linux v1.0     |  | Linux v2.0     |            |
|  |bootslot  |  | gateway-monitor|  | gateway-monitor|            |
|  |bootcount |  | v1.0 (active)  |  | v2.0 (target)  |            |
|  |bootlimit |  +----------------+  +----------------+            |
|  +----+-----+                                                    |
|       |                                                          |
|  +----+--------------------------------------------------+       |
|  |              U-Boot 2024.01                           |       |
|  |  1. loads boot.scr from Slot A at every boot          |       |
|  |  2. reads bootslot/bootcount/bootlimit from vda1 FAT  |       |
|  |  3. increments bootcount on Slot B boot attempt       |       |
|  |  4. ROLLBACK to Slot A if bootcount >= bootlimit (3)  |       |
|  |  5. auto-reboot after 3s if kernel load fails         |       |
|  +-------------------------------------------------------+       |
|                                                                  |
|  +-------------------------------------------------------+       |
|  |  SWUpdate v2026.05                                    |       |
|  |  - receives .swu package via HTTP (port 8080)         |       |
|  |  - verifies hardware compatibility (qemuarm:1.0)      |       |
|  |  - writes image to inactive slot (/dev/vda3)          |       |
|  |  - runs postinstall.sh → writes bootslot=b to vda1    |       |
|  +-------------------------------------------------------+       |
+------------------------------------------------------------------+
```

---

## Stack

| Component        | Details                        |
|------------------|--------------------------------|
| Build system     | Yocto Project — Scarthgap 5.0  |
| Target machine   | QEMU ARM (qemuarm)             |
| Bootloader       | U-Boot 2024.01                 |
| Update manager   | SWUpdate v2026.05              |
| Kernel           | Linux 6.6.127-yocto-standard   |
| Partition scheme | A/B dual partition with rollback|
| Architecture     | ARMv7 (Cortex-A15)             |
| Host OS          | Ubuntu 22.04 LTS               |

---

## Project Structure

```
yocto-ota-swupdate-qemu/
├── .github/workflows/build.yml            → CI/CD GitHub Actions
├── .gitignore
├── README.md
├── build/conf/
│   ├── bblayers.conf                      → poky + meta-oe + meta-swupdate + meta-moez
│   └── local.conf                         → MACHINE=qemuarm + IMAGE_ROOTFS_EXTRA_SPACE=65536
├── meta-moez/
│   ├── recipes-app/gateway-monitor/
│   │   ├── files/gateway-monitor-v1.c     → C source v1.0 (Slot A)
│   │   ├── files/gateway-monitor-v2.c     → C source v2.0 (Slot B)
│   │   └── gateway-monitor_1.0.bb         → BitBake recipe v1.0
│   ├── recipes-bsp/u-boot/
│   │   ├── files/qemu_arm_virt_defconfig_fragment.cfg → ENV_IS_NOWHERE + BOOTCOMMAND
│   │   └── u-boot_%.bbappend
│   ├── recipes-core/
│   │   ├── base-files/base-files_%.bbappend   → hwrevision + SWUpdate conf.d
│   │   ├── boot-confirm/
│   │   │   ├── boot-confirm_1.0.bb            → Boot confirmation (init.d S99)
│   │   │   └── files/boot-confirm.sh          → Resets bootcount=0 on Slot B boot
│   │   ├── images/gateway-image.bb            → Custom image recipe
│   │   └── init-ifupdown/init-ifupdown_%.bbappend → eth0 auto DHCP
│   └── recipes-swupdate/swupdate/swupdate_%.bbappend → SWUpdate ARGS
├── scripts/
│   ├── create-disk.sh                     → Creates GPT disk (vda1+vda2+vda3)
│   ├── run-qemu.sh                        → Launches QEMU
│   └── setup.sh                           → Initializes build env
└── swu/
    ├── create-swu-corrupted.sh            → Builds corrupted OTA (rollback test)
    ├── create-swu.sh                      → Builds gateway-update-v2.0.swu
    ├── postinstall.sh                     → Writes bootslot=b to vda1 FAT
    ├── sw-description                     → OTA descriptor (v1.0 → v2.0)
    └── sw-description-corrupted           → OTA descriptor for rollback test
```

---

## OTA Update Flow

```
1. System boots on Slot A (v1.0) — normal operation
         |
2. SWUpdate receives update package (v2.0)
         |
3. SWUpdate writes v2.0 to Slot B (Slot A untouched)
         |
4. SWUpdate notifies U-Boot: "try Slot B next boot"
         |
5. System reboots
         |
         +---> Slot B boots OK?
               |
               YES --> Slot B becomes active, Slot A = backup
               |
               NO  --> U-Boot detects failure after 3 attempts
                       --> Automatic rollback to Slot A
```

---

## Roadmap

- [x] Phase 1 — Yocto environment setup
- [x] Phase 1 — First core-image-minimal build for qemuarm
- [x] Phase 2 — Add meta-swupdate layer
- [x] Phase 2 — Gateway image with SWUpdate + SSH + web interface
- [x] Phase 3 — A/B disk layout (GPT: uboot-env + Slot A + Slot B)
- [x] Phase 3 — U-Boot 2024.01 built by Yocto, bootcmd loads boot.scr automatically
- [x] Phase 3 — boot.scr reads bootslot from vda1 FAT (persistent)
- [x] Phase 3 — OTA pipeline tested end-to-end — zero manual intervention
- [x] Phase 3 — postinstall.sh switches bootslot after successful OTA
- [x] Phase 4 — Automatic rollback (bootcount/bootlimit via U-Boot + FAT env on vda1)
- [x] Phase 4 — CI/CD pipeline (GitHub Actions — project validation on every push)
- [x] Phase 4 — SWUpdate package signing (RSA/AES)

---

## Why This Project

Most junior embedded engineers know how to compile a kernel or build a rootfs. Far fewer understand how to **safely update** a deployed embedded system without risking a brick.

This project implements the same OTA architecture used in:
- Industrial IoT devices
- Automotive ECUs (SOTA updates)
- Defense and aerospace embedded systems (Thales, Airbus, Collins...)

---

## Build Results

### Phase 1 — Yocto Image (Completed)

```
Build system   : Yocto Project Scarthgap 5.0.18
Target         : QEMU ARM (qemuarm)
Kernel         : Linux 6.6.127-yocto-standard
Architecture   : ARMv7 Processor rev 0 (v7l) — 4 CPUs
Compiler       : arm-poky-linux-gnueabi-gcc 13.4.0
Tasks executed : 4060 tasks — 0 errors
```

### Image Produced

```
zImage (kernel)          :  7.1 MB
core-image-minimal.ext4  : 14.0 MB
Total rootfs used        :  8.1 MB / 11.4 MB
```

### Boot Results (QEMU)

```
CPU      : ARMv7 Processor rev 0 (v7l) x4 cores
RAM      : 232 MB available / 256 MB total
Rootfs   : ext4 mounted r/w — /dev/vda
Network  : eth0 UP — 192.168.7.2/24
Swap     : none (embedded configuration)
Status   : BOOT SUCCESSFUL
```

```
root@qemuarm:~# uname -a
Linux qemuarm 6.6.127-yocto-standard #1 SMP PREEMPT armv7l GNU/Linux
```
## Phase 2 — Gateway Image with SWUpdate (Completed)

### Image Produced

​```
Image name     : gateway-image
Rootfs size    : 22 MB
Added packages : SWUpdate v2026.05, Dropbear SSH, iproute2, ethtool, procps
Tasks executed : 4298 tasks (4043 from cache — 6 min build)
​```

### Boot Results (QEMU)

```
SWUpdate v2026.05        : started automatically at boot ✅
Dropbear SSH server      : running ✅
Mongoose web server      : listening on port 8080 ✅
U-Boot bootloader        : detected by SWUpdate ✅
Network eth0             : UP — 192.168.7.2/24 ✅
OTA web interface        : accessible at http://192.168.7.2:8080 ✅
```
### Phase 3 — A/B OTA Pipeline with U-Boot Automatic Slot Selection (Completed)
```
    Disk layout        : GPT 300MB — vda1 (uboot-env) + vda2 (Slot A 150MB) + vda3 (Slot B 150MB)
    Bootloader         : U-Boot 2024.01 built by Yocto for qemuarm
    Boot script        : boot.scr loaded automatically by U-Boot bootcmd
    Slot selection  : U-Boot reads bootslot from vda1 FAT (persistent)
    Network            : eth0 configured automatically via DHCP at boot
    hwrevision         : qemuarm:1.0 embedded permanently in rootfs
    SWUpdate config    : -H qemuarm:1.0 configured via /etc/swupdate/conf.d/
    OTA package     : gateway-update-v2.0.swu (86MB — full ext4 with kernel + boot.scr)
    Transfer method    : HTTP POST via curl to SWUpdate web interface (port 8080)
    postinstall.sh  : writes bootslot=b to vda1 FAT after OTA
    SWUpdate result    : SWUPDATE successful ✅
    Reboot             : U-Boot reads bootslot=b → boots Slot B automatically ✅

    gateway-monitor v1.0 (Slot A)        gateway-monitor v2.0 (Slot B)
    ----------------------------         ------------------------------
    Version  : 1.0.0                     Version  : 2.0.0
    Slot     : A (active)                Slot     : B (active)
    STATUS   : NOMINAL                   *** OTA UPDATE APPLIED ***
                                         CPU load, RAM, Firewall, Packets
                                         STATUS   : NOMINAL - ENHANCED

    Full OTA flow — zero manual intervention:
    Boot Slot A (v1.0) → curl send .swu → SWUPDATE successful
    → bootslot=b written → reboot → U-Boot reads bootslot=b
    → Boot Slot B (v2.0) automatically ✅
```
### Phase 4 — Automatic Rollback via U-Boot bootcount/bootlimit (Completed)
```
    U-Boot env         : vda1 FAT partition — bootslot, bootcount, bootlimit
    boot.scr           : reads/writes bootcount to vda1 FAT on every boot attempt
    Rollback trigger   : bootcount >= bootlimit (3 failed attempts)
    Reboot on failure  : automatic reboot after 3s if kernel load fails
    postinstall.sh     : writes bootslot=b + bootcount=0 to vda1 FAT after OTA
    boot-confirm       : resets bootcount=0 on successful Slot B boot (init.d S99)
    Test packages      : gateway-update-v2.0.swu (valid OTA) + gateway-update-corrupted.swu (rollback test)

    Rollback flow — zero manual intervention:
    Corrupted OTA installed on Slot B
    → bootcount=1 → kernel load failed → reboot in 3s (automatic)
    → bootcount=2 → kernel load failed → reboot in 3s (automatic)
    → bootcount=3 >= bootlimit → ROLLBACK: reverting to Slot A (automatic)
    → Linux v1.0 Slot A recovered ✅
```
### CI/CD — GitHub Actions (Completed)

```
Workflow       : .github/workflows/build.yml
Trigger        : every push to main branch
Validation     : project structure, sw-description, U-Boot config, gateway-monitor sources
Status         : passing ✅
```
### Phase 4 — RSA Package Signing (Completed)
```
    Signing algorithm  : RSA 2048-bit + SHA256 (opensslRSA)
    Private key        : swu/keys/swupdate-private.pem (gitignored)
    Public key         : embedded in rootfs at /etc/swupdate/swupdate-public.pem
    Config             : swupdate.cfg loaded via -f flag with public-key-file
    sw-description     : signed automatically by create-swu.sh
    Hash verification  : SHA256 hash required for each image and script

    3 scenarios tested:
    1. OTA non signée      → rejetée immédiatement (sw-description.sig manquant) ✅
    2. OTA signée corrompue → acceptée RSA → installée → rollback auto 3 tentatives ✅
    3. OTA signée valide   → Verified OK → Slot B v2.0 bootée ✅
```
---

## Author

**Moez Chagraoui** — Embedded Systems Engineer  
Double degree: INP-ENSEEIHT Toulouse (ACISE) + ENIT Tunis  
[LinkedIn](https://linkedin.com/in/moez-chagraoui) • [GitHub](https://github.com/Moez-La)
