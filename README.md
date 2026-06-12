# yocto-ota-swupdate-qemu

![Status](https://img.shields.io/badge/status-completed-brightgreen)
![Platform](https://img.shields.io/badge/platform-QEMU%20ARM-blue)
![Build](https://img.shields.io/badge/build%20system-Yocto%20Scarthgap-green)
![SWUpdate](https://img.shields.io/badge/SWUpdate-v2026.05-brightgreen)
![CI](https://github.com/Moez-La/yocto-ota-swupdate-qemu/actions/workflows/build.yml/badge.svg)

Embedded Linux image built with **Yocto Project (Scarthgap)** for QEMU ARM — featuring a complete OTA (Over-The-Air) update pipeline with **SWUpdate**, **A/B partition scheme**, automatic rollback via **U-Boot**, and **RSA package signing**. OTA updates can be sent from any device on any network via internet tunnel.

---

## Demo

### Local OTA — Same PC, Separate Terminal

> curl sends the signed `.swu` package directly to SWUpdate via `localhost:8080`. Three security scenarios demonstrated: unsigned package rejected, signed corrupted package triggers automatic rollback after 3 boot failures, signed valid package installs successfully on Slot B.

<video src="demo/demo-local.mp4" controls width="100%"></video>

---

### Remote OTA — Smartphone via 4G Mobile Data

> The `.swu` package is uploaded from a smartphone connected on a completely different network (4G mobile data) through a public ngrok tunnel. Three security scenarios demonstrated remotely: unsigned package rejected, signed corrupted package triggers automatic rollback after 3 boot failures, signed valid package installs successfully on Slot B — demonstrating real-world remote OTA from anywhere in the world.

<video src="demo/demo-remote.mp4" controls width="100%"></video>

---

## Overview

This project demonstrates a production-ready embedded Linux update mechanism — the kind used in industrial equipment, automotive systems, and defense electronics deployed in the field.

A custom **Network Gateway Monitor** application (written in C) runs on the embedded system and displays real-time network statistics read directly from the Linux kernel via `/proc`. The application exists in two versions to demonstrate the OTA update:

- **v1.0** — Basic monitoring: IP address, RX/TX bytes, status
- **v2.0** — Enhanced monitoring: adds CPU load, RAM usage, packet counter, and firewall status

The system receives the v2.0 update remotely via HTTP, SWUpdate verifies the RSA signature and SHA256 hashes, installs it safely on the inactive slot, and the new features become immediately visible — demonstrating a real OTA update on an ARMv7 embedded system.

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
|  |  - verifies RSA signature (sw-description.sig)        |       |
|  |  - verifies SHA256 hash of each artifact              |       |
|  |  - verifies hardware compatibility (qemuarm:1.0)      |       |
|  |  - writes image to inactive slot (/dev/vda3)          |       |
|  |  - runs postinstall.sh → writes bootslot=b to vda1    |       |
|  +-------------------------------------------------------+       |
|                                                                  |
|  +-------------------------------------------------------+       |
|  |  libubootenv                                          |       |
|  |  - fw_env.config → /var/lib/swupdate/uboot.env       |       |
|  |  - allows SWUpdate to persist update state           |       |
|  |  - enables clean SWUPDATE successful log             |       |
|  +-------------------------------------------------------+       |
|                                                                  |
|  +-------------------------------------------------------+       |
|  |  ngrok tunnel (run-qemu.sh)                           |       |
|  |  - exposes port 8080 to public internet               |       |
|  |  - URL displayed automatically at QEMU startup        |       |
|  |  - enables remote OTA from any device/network         |       |
|  +-------------------------------------------------------+       |
+------------------------------------------------------------------+
```

---

## Stack

| Component        | Details                          |
|------------------|----------------------------------|
| Build system     | Yocto Project — Scarthgap 5.0    |
| Target machine   | QEMU ARM (qemuarm)               |
| Bootloader       | U-Boot 2024.01                   |
| Update manager   | SWUpdate v2026.05                |
| Kernel           | Linux 6.6.127-yocto-standard     |
| Partition scheme | A/B dual partition with rollback  |
| Architecture     | ARMv7 (Cortex-A15)               |
| Signing          | RSA 2048-bit + SHA256            |
| Env management   | libubootenv (file-based)         |
| Remote tunnel    | ngrok (integrated in run-qemu.sh)|
| Host OS          | Ubuntu 22.04 LTS                 |

---

## Project Structure

```
yocto-ota-swupdate-qemu/
├── .github/workflows/build.yml            → CI/CD GitHub Actions (validation on push)
├── .gitignore
├── README.md
├── demo/
│   ├── demo-local.gif                     → Local OTA demo (curl from same PC)
│   └── demo-remote.gif                    → Remote OTA demo (smartphone via 4G + ngrok)
├── build/conf/
│   ├── bblayers.conf                      → poky + meta-oe + meta-swupdate + meta-moez
│   └── local.conf                         → MACHINE=qemuarm + IMAGE_ROOTFS_EXTRA_SPACE=65536
├── meta-moez/
│   ├── recipes-app/gateway-monitor/
│   │   ├── files/gateway-monitor-v1.c     → C source v1.0 (Slot A — basic monitoring)
│   │   ├── files/gateway-monitor-v2.c     → C source v2.0 (Slot B — enhanced monitoring)
│   │   └── gateway-monitor_1.0.bb         → BitBake recipe v1.0
│   ├── recipes-bsp/u-boot/
│   │   ├── files/qemu_arm_virt_defconfig_fragment.cfg → ENV_IS_NOWHERE + BOOTCOMMAND
│   │   └── u-boot_%.bbappend              → U-Boot custom config fragment
│   ├── recipes-core/
│   │   ├── base-files/base-files_%.bbappend   → hwrevision + fw_env.config + SWUpdate conf.d
│   │   ├── boot-confirm/
│   │   │   ├── boot-confirm_1.0.bb            → Boot confirmation recipe (init.d S99)
│   │   │   └── files/boot-confirm.sh          → Resets bootcount=0 on successful Slot B boot
│   │   ├── images/gateway-image.bb            → Custom image recipe (SWUpdate + SSH + libubootenv)
│   │   └── init-ifupdown/init-ifupdown_%.bbappend → eth0 auto DHCP at boot
│   └── recipes-swupdate/swupdate/
│       ├── swupdate_%.bbappend            → SWUpdate ARGS (-l 3) + RSA public key + signing config
│       └── files/
│           ├── swupdate-public.pem        → RSA public key embedded in rootfs
│           ├── swupdate-runtime.cfg       → SWUpdate runtime config (public-key-file + loglevel=3)
│           └── swupdate-signing.cfg       → Kconfig fragment (SIGNED_IMAGES=y + SIGALG_RAWRSA=y)
├── scripts/
│   ├── create-disk.sh                     → Creates GPT disk (vda1 FAT + vda2 SlotA + vda3 SlotB)
│   ├── run-qemu.sh                        → Launches QEMU + ngrok tunnel (URL displayed at startup)
│   └── setup.sh                           → Clones layers and initializes build env
└── swu/
    ├── keys/
    │   └── swupdate-public.pem            → RSA public key (private key gitignored)
    ├── create-swu.sh                      → Builds gateway-update-v2.0.swu (signed + SHA256)
    ├── create-swu-corrupted.sh            → Builds unsigned corrupted OTA (RSA rejection test)
    ├── create-swu-corrupted-signed.sh     → Builds signed corrupted OTA (rollback test)
    ├── postinstall.sh                     → Writes bootslot=b to vda1 FAT after OTA
    ├── sw-description                     → OTA descriptor (v1.0 → v2.0) with SHA256 hashes
    ├── sw-description.sig                 → RSA signature of sw-description
    └── sw-description-corrupted           → OTA descriptor for unsigned rollback test
```

---

## OTA Update Flow

```
1. System boots on Slot A (v1.0) — normal operation
         |
2. SWUpdate receives update package via HTTP (local or ngrok)
         |
3. SWUpdate verifies RSA signature + SHA256 hashes
         |
         +---> Signature invalid? → REJECTED immediately ✅
         |
4. SWUpdate writes v2.0 to Slot B (Slot A untouched)
         |
5. postinstall.sh writes bootslot=b to vda1 FAT
         |
6. libubootenv persists update state → SWUPDATE successful ! ✅
         |
7. System reboots automatically
         |
         +---> Slot B boots OK?
               |
               YES → boot-confirm resets bootcount=0
                   → Slot B v2.0 becomes active ✅
               |
               NO  → U-Boot increments bootcount automatically
                   → auto-reboot after 3s if kernel fails
                   → ROLLBACK to Slot A after 3 failed attempts ✅
```

---

## Remote OTA Flow

```
Smartphone (4G) ──────► ngrok public URL ──────► localhost:8080
                                                        │
                                              SWUpdate receives .swu
                                                        │
                                              RSA signature verified
                                                        │
                                              Image written to Slot B
                                                        │
                                              SWUPDATE successful ! ✅
                                                        │
                                              System reboots → Slot B v2.0
```

---

## Security Model

```
3 scenarios validated:

1. OTA unsigned (no sw-description.sig)
   → Rejected immediately by SWUpdate ✅
   → No installation, Slot A untouched

2. OTA signed + corrupted image (valid RSA, empty ext4)
   → Verified OK by RSA ✅
   → Installed on Slot B
   → kernel load fails → bootcount=1,2,3 → ROLLBACK to Slot A ✅

3. OTA signed + valid v2.0 image
   → Verified OK by RSA ✅
   → Installed on Slot B
   → Slot B boots successfully → v2.0 active ✅
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
- [x] Phase 4 — SWUpdate package signing (RSA 2048-bit + SHA256)
- [x] Phase 4 — libubootenv file-based env — clean SWUPDATE successful logs
- [x] Bonus — Remote OTA via internet from smartphone (ngrok integrated in run-qemu.sh)

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

```
zImage (kernel)          :  7.1 MB
core-image-minimal.ext4  : 14.0 MB
Total rootfs used        :  8.1 MB / 11.4 MB
```

```
CPU      : ARMv7 Processor rev 0 (v7l) x4 cores
RAM      : 232 MB available / 256 MB total
Rootfs   : ext4 mounted r/w — /dev/vda
Network  : eth0 UP — 192.168.7.2/24
Status   : BOOT SUCCESSFUL
```

---

### Phase 2 — Gateway Image with SWUpdate (Completed)

```
Image name     : gateway-image
Rootfs size    : 22 MB
Added packages : SWUpdate v2026.05, Dropbear SSH, iproute2, ethtool, procps
Tasks executed : 4298 tasks (4043 from cache — 6 min build)
```

```
SWUpdate v2026.05        : started automatically at boot ✅
Dropbear SSH server      : running ✅
Mongoose web server      : listening on port 8080 ✅
U-Boot bootloader        : detected by SWUpdate ✅
Network eth0             : UP — 192.168.7.2/24 ✅
OTA web interface        : accessible at http://192.168.7.2:8080 ✅
```

---

### Phase 3 — A/B OTA Pipeline (Completed)

```
Disk layout     : GPT 300MB — vda1 (uboot-env FAT) + vda2 (Slot A 150MB) + vda3 (Slot B 150MB)
Bootloader      : U-Boot 2024.01 built by Yocto for qemuarm
Boot script     : boot.scr loaded automatically by U-Boot bootcmd
Slot selection  : U-Boot reads bootslot from vda1 FAT (persistent)
OTA package     : gateway-update-v2.0.swu (86MB — full ext4 with kernel + boot.scr)
Transfer method : HTTP POST via curl or web interface (port 8080)
postinstall.sh  : writes bootslot=b to vda1 FAT after OTA
```

```
gateway-monitor v1.0 (Slot A)        gateway-monitor v2.0 (Slot B)
----------------------------         ------------------------------
Version  : 1.0.0                     Version  : 2.0.0
Slot     : A (active)                Slot     : B (active)
STATUS   : NOMINAL                   *** OTA UPDATE APPLIED ***
                                     CPU load, RAM, Firewall, Packets
                                     STATUS   : NOMINAL - ENHANCED
```

---

### Phase 4 — Automatic Rollback (Completed)

```
U-Boot env       : vda1 FAT partition — bootslot, bootcount, bootlimit
Rollback trigger : bootcount >= bootlimit (3 failed attempts)
Reboot on failure: automatic reboot after 3s if kernel load fails
boot-confirm     : resets bootcount=0 on successful Slot B boot (init.d S99)
```

```
Rollback flow:
Corrupted OTA installed on Slot B
→ bootcount=1 → kernel load failed → reboot in 3s
→ bootcount=2 → kernel load failed → reboot in 3s
→ bootcount=3 >= bootlimit → ROLLBACK: reverting to Slot A ✅
```

---

### Phase 4 — CI/CD GitHub Actions (Completed)

```
Workflow   : .github/workflows/build.yml
Trigger    : every push to main branch
Validation : project structure, sw-description, U-Boot config, gateway-monitor sources
Status     : passing ✅
```

---

### Phase 4 — RSA Package Signing (Completed)

```
Signing algorithm : RSA 2048-bit + SHA256 (opensslRSA)
Private key       : swu/keys/swupdate-private.pem (gitignored)
Public key        : embedded in rootfs at /etc/swupdate/swupdate-public.pem
Kconfig           : CONFIG_SIGNED_IMAGES=y + CONFIG_SIGALG_RAWRSA=y
sw-description    : signed automatically by create-swu.sh via openssl dgst
Hash verification : SHA256 hash required for each image and script
```

---

### Phase 4 — libubootenv + Clean Logs (Completed)

```
fw_env.config     : /var/lib/swupdate/uboot.env (file-based, no raw partition needed)
libubootenv-bin   : fw_printenv / fw_setenv available in rootfs
loglevel          : 3 (INFO only — no TRACE/DEBUG noise)
Result            : SWUPDATE successful ! displayed cleanly ✅
```

```
[INFO] : SWUPDATE started  : Software Update started !
[INFO] : SWUPDATE running  : Installation in progress
[INFO] : SWUPDATE successful ! SWUPDATE successful !
[INFO] : No SWUPDATE running : Waiting for requests...
```

---

### Bonus — Remote OTA via Internet (Completed)

```
Tool              : ngrok (integrated in run-qemu.sh)
Trigger           : ngrok starts automatically with QEMU
URL display       : public URL printed at startup
Test              : OTA sent from smartphone on 4G — different network ✅
Security          : RSA signature ensures only authorized .swu are accepted
```

```
run-qemu.sh output:
=== ngrok URL ===
https://diary-shower-anthology.ngrok-free.dev
=================
[QEMU boots...]
```

---

## Author

**Moez Chagraoui** — Embedded Systems Engineer  
Double degree: INP-ENSEEIHT Toulouse (ACISE) + ENIT Tunis  
[LinkedIn](https://linkedin.com/in/moez-chagraoui) • [GitHub](https://github.com/Moez-La)
