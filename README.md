# yocto-ota-swupdate-qemu

![Status](https://img.shields.io/badge/status-completed-brightgreen)
![Platform](https://img.shields.io/badge/platform-QEMU%20ARM-blue)
![Build](https://img.shields.io/badge/build%20system-Yocto%20Scarthgap-green)
![SWUpdate](https://img.shields.io/badge/SWUpdate-v2026.05-brightgreen)
![CI](https://github.com/Moez-La/yocto-ota-swupdate-qemu/actions/workflows/build.yml/badge.svg)

> **Related repository:** the cloud OTA server used by the Phase 7 OTA Agent is at **[github.com/Moez-La/ota-server](https://github.com/Moez-La/ota-server)** (FastAPI on Render).

Embedded Linux image built with **Yocto Project (Scarthgap)** for QEMU ARM — featuring a complete OTA (Over-The-Air) update pipeline with **SWUpdate**, **A/B partition scheme**, automatic rollback via **U-Boot**, **RSA package signing**, **U-Boot Secure Boot** (FIT image signature verification), and **dynamic A/B slot targeting**. OTA updates can be sent from any device on any network via internet tunnel.

---

## Demo

### Local OTA — Same PC, Separate Terminal

> curl sends the signed `.swu` package directly to SWUpdate via `localhost:8080`. Three security scenarios demonstrated: unsigned package rejected, signed corrupted package triggers automatic rollback after 3 boot failures, signed valid package installs successfully on Slot B.

[![Local OTA Demo](https://img.youtube.com/vi/q1bFOdNw2aE/hqdefault.jpg)](https://youtu.be/q1bFOdNw2aE)

---

### Remote OTA — Smartphone via 4G Mobile Data

> The `.swu` package is uploaded from a smartphone connected on a completely different network (4G mobile data) through a public ngrok tunnel. Three security scenarios demonstrated remotely: unsigned package rejected, signed corrupted package triggers automatic rollback after 3 boot failures, signed valid package installs successfully on Slot B.

[![Remote OTA Demo](https://img.youtube.com/vi/6k4kBoaxgzM/maxresdefault.jpg)](https://youtu.be/6k4kBoaxgzM)

---

### Phase 5 & 6 — Secure Boot + Dynamic A/B Slot + v1→v2→v3

> Full end-to-end demo: system starts on Slot A with gateway-monitor v1.0. First OTA sends v2.0 — preinst.sh detects Slot A as active and automatically targets Slot B (inactive). U-Boot verifies the RSA-signed FIT image before booting. Second OTA sends v3.0 from Slot B — preinst.sh detects Slot B and targets Slot A. The active slot is read dynamically from `/proc/cmdline` at every boot — never hardcoded.

[![Phase 5 & 6 Demo](https://img.youtube.com/vi/ruY73xMhIy8/hqdefault.jpg)](https://youtu.be/ruY73xMhIy8)

---

## Overview

This project demonstrates a production-ready embedded Linux update mechanism — the kind used in industrial equipment, automotive systems, and defense electronics deployed in the field.

A custom **Network Gateway Monitor** application (written in C) runs on the embedded system and displays real-time network statistics read directly from the Linux kernel via `/proc`. The application now exists in three versions, each with the active slot read dynamically from `/proc/cmdline`:

- **v1.0** — Basic monitoring: IP address, RX/TX bytes, status
- **v2.0** — Enhanced monitoring: CPU load, RAM usage, packet counter, firewall status
- **v3.0** — Advanced monitoring: real-time bandwidth RX/TX (KB/s), dropped packets, process count, adaptive health monitor

The system receives updates remotely via HTTP, SWUpdate verifies the RSA signature and SHA256 hashes, installs safely on the **dynamically detected inactive slot**, and the new features become immediately visible after reboot — demonstrating a real OTA update on an ARMv7 embedded system with full chain of trust.

**Phase 7 (new)** adds a second update model. In addition to the *push* model above (an operator sends the `.swu` to SWUpdate), a **C++ OTA Agent** running on the device now *pulls* updates automatically from a **FastAPI cloud server hosted on Render** ([Moez-La/ota-server](https://github.com/Moez-La/ota-server)): it polls the server, downloads a newer signed `.swu`, installs it on the inactive slot with SWUpdate and reboots — with no manual action on the device.

---

## Architecture

```
+------------------------------------------------------------------+
|                         QEMU ARM (qemuarm)                       |
|                                                                  |
|  +----------+  +----------------+  +----------------+            |
|  |   vda1   |  |     vda2       |  |     vda3       |            |
|  | FAT 1MB  |  |  Slot A 400MB  |  |  Slot B 400MB  |            |
|  |uboot.env |  | Linux vX.0     |  | Linux vY.0     |            |
|  |bootslot  |  | kernel.itb     |  | kernel.itb     |            |
|  |bootcount |  | (signed FIT)   |  | (signed FIT)   |            |
|  |bootlimit |  +----------------+  +----------------+            |
|  +----+-----+                                                    |
|       |                                                          |
|  +----+--------------------------------------------------+       |
|  |              U-Boot 2024.01 (Secure Boot)             |       |
|  |  - RSA public key embedded in control DTB at build    |       |
|  |  - loads boot.scr from active slot at every boot      |       |
|  |  - reads bootslot/bootcount/bootlimit from vda1 FAT   |       |
|  |  - verifies FIT image RSA signature before boot       |       |
|  |    -> Verified OK -> boots kernel                     |       |
|  |    -> Invalid signature -> boot REFUSED               |       |
|  |  - increments bootcount on new slot boot attempt      |       |
|  |  - ROLLBACK to previous slot if bootcount >= 3        |       |
|  +-------------------------------------------------------+       |
|                                                                  |
|  +-------------------------------------------------------+       |
|  |  SWUpdate v2026.05                                    |       |
|  |  - receives .swu package via HTTP (port 8080)         |       |
|  |  - runs preinst.sh -> detects active slot from vda1   |       |
|  |  - creates /dev/target_slot -> inactive slot device   |       |
|  |  - verifies RSA signature + SHA256 hashes             |       |
|  |  - writes image to /dev/target_slot (always inactive) |       |
|  |  - runs postinstall.sh -> writes opposite bootslot    |       |
|  |    to vda1 FAT + creates uboot.env on target slot     |       |
|  +-------------------------------------------------------+       |
|                                                                  |
|  +-------------------------------------------------------+       |
|  |  SWUpdate flags: -m -M                                |       |
|  |  - disables SWUpdate's own state/transaction markers  |       |
|  |  - slot switching handled by preinst/postinstall + U-Boot |   |
|  |  - gives a clean SWUPDATE successful log              |       |
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

### Phase 7 — Cloud OTA Server + OTA Agent (added)

```
        +--------------------------------------+
        |  Cloud OTA Server (Render)           |
        |  repo: Moez-La/ota-server (FastAPI)  |
        |  /health  /version  /firmware /upload|
        +------------------^-------------------+
                           | HTTPS + API key, poll every 60 s
+--------------------------+-----------------------------------+
|  QEMU ARM (512 MB RAM)                                       |
|  OTA Agent (C++17 + libcurl)                                 |
|   -> reads /var/lib/swupdate/ota-version                     |
|   -> downloads .swu to /ota (200 MB tmpfs)                   |
|   -> runs SWUpdate on the inactive slot, then reboots        |
+--------------------------------------------------------------+
```

> **Notes:**
> - The disk is **800 MB** with **400 MB slots** (vda2 / vda3), so larger images fit.
> - SWUpdate is launched with `-m -M` (disable state / transaction markers). Slot switching and boot confirmation are handled by `preinst.sh`, `postinstall.sh` and U-Boot, so SWUpdate does not need to persist its own update state through libubootenv.

---

## Stack

| Component          | Details                                          |
|--------------------|--------------------------------------------------|
| Build system       | Yocto Project — Scarthgap 5.0                    |
| Target machine     | QEMU ARM (qemuarm)                               |
| Bootloader         | U-Boot 2024.01 (Secure Boot, FIT signing)        |
| Update manager     | SWUpdate v2026.05                                |
| Kernel             | Linux 6.6.127-yocto-standard                     |
| Partition scheme   | A/B dual partition with rollback                 |
| Architecture       | ARMv7 (Cortex-A15)                               |
| OTA Signing        | RSA 2048-bit + SHA256                            |
| Boot Signing       | RSA 2048-bit FIT image (U-Boot Verified Boot)    |
| Slot targeting     | Dynamic — preinst.sh detects active slot at runtime |
| Env management     | U-Boot env on vda1 FAT + SWUpdate run with -m -M |
| Remote tunnel      | ngrok (integrated in run-qemu.sh)                |
| Host OS            | Ubuntu 22.04 LTS                                 |
| OTA Agent (Phase 7)| C++17 + libcurl + nlohmann-json, init script autostart |
| Cloud server       | Python FastAPI on Render — [ota-server](https://github.com/Moez-La/ota-server) |
| QEMU RAM           | 512 MB (Phase 7)                                 |

---

## Project Structure

```
yocto-ota-swupdate-qemu/
├── .github/workflows/build.yml
├── .gitignore
├── README.md
├── demo/
│   ├── demo-local.mp4
│   └── demo-remote.mp4
├── build/conf/
│   ├── bblayers.conf
│   └── local.conf
├── meta-moez/
│   ├── recipes-app/ota-agent/             -> Phase 7: C++ OTA Agent
│   │   ├── files/ota-agent.cpp            -> polls cloud, downloads, installs, reboots
│   │   ├── files/ota-agent-init           -> sysvinit autostart script
│   │   ├── files/ota-agent.service        -> systemd unit
│   │   ├── files/ota-version              -> default version file
│   │   └── ota-agent_1.0.bb
│   ├── recipes-app/gateway-monitor/
│   │   ├── files/gateway-monitor-v1.c     -> C source v1.0 (dynamic slot, basic monitoring)
│   │   ├── files/gateway-monitor-v2.c     -> C source v2.0 (dynamic slot, enhanced monitoring)
│   │   ├── files/gateway-monitor-v3.c     -> C source v3.0 (bandwidth, health, process count)
│   │   └── gateway-monitor_1.0.bb
│   ├── recipes-bsp/u-boot/
│   │   ├── files/qemu_arm_virt_defconfig_fragment.cfg
│   │   ├── files/secureboot.cfg           -> CONFIG_FIT_SIGNATURE + CONFIG_RSA
│   │   ├── files/qemu-arm-pubkey.dtsi     -> RSA public key embedded in U-Boot DTB
│   │   ├── files/fit-public.crt           -> RSA public certificate
│   │   └── u-boot_%.bbappend
│   ├── recipes-core/
│   │   ├── base-files/base-files_%.bbappend
│   │   ├── boot-confirm/
│   │   │   ├── boot-confirm_1.0.bb
│   │   │   └── files/boot-confirm.sh
│   │   ├── images/gateway-image.bb
│   │   └── init-ifupdown/init-ifupdown_%.bbappend
│   └── recipes-swupdate/swupdate/
│       ├── swupdate_%.bbappend
│       └── files/
│           ├── swupdate-public.pem
│           ├── swupdate-runtime.cfg
│           └── swupdate-signing.cfg
├── secureboot/
│   ├── keys/
│   │   └── fit-public.crt                 -> RSA public certificate (private key gitignored)
│   ├── fit/
│   │   ├── kernel.its                     -> FIT Image Tree Source
│   │   ├── kernel.itb                     -> Signed FIT image (kernel + RSA signature)
│   │   └── pubkey.dtb                     -> Public key as device tree node
│   ├── boot.cmd                           -> U-Boot boot script (A/B + rollback + FIT verify)
│   └── boot.scr                           -> Compiled U-Boot boot script
├── scripts/
│   ├── create-disk.sh
│   ├── run-qemu.sh
│   └── setup.sh
└── swu/
    ├── keys/
    │   └── swupdate-public.pem
    ├── create-swu.sh                      -> Builds signed .swu with preinst + postinstall (usage: bash swu/create-swu.sh <version>, e.g. 3.0.0)
    ├── create-swu-corrupted.sh
    ├── create-swu-corrupted-signed.sh
    ├── preinst.sh                         -> Detects active slot, creates /dev/target_slot
    ├── postinstall.sh                     -> Reads vda1 FAT, writes opposite bootslot
    ├── sw-description                     -> device=/dev/target_slot (dynamic)
    ├── sw-description.sig
    └── sw-description-corrupted
```

---

## OTA Update Flow — Dynamic Slot Targeting

```
System active on Slot X (any version)
         |
SWUpdate receives .swu package via HTTP
         |
preinst.sh runs BEFORE image write:
  - mounts vda1 FAT
  - reads bootslot (X) from uboot.env
  - computes inactive slot Y (opposite of X)
  - creates symlink: /dev/target_slot -> /dev/vdaY
         |
SWUpdate verifies RSA signature + SHA256 hashes
         |
         +---> Signature invalid? -> REJECTED immediately
         |
SWUpdate writes new image to /dev/target_slot (Slot Y — always inactive)
         |
postinstall.sh runs AFTER image write:
  - re-reads vda1 FAT independently
  - writes bootslot=Y + bootcount=0 to vda1 FAT
  - creates /var/lib/swupdate/uboot.env on Slot Y
  -> SWUPDATE successful !
         |
System reboots
         |
U-Boot reads bootslot=Y from vda1 FAT
         |
U-Boot loads kernel.itb from Slot Y
         |
U-Boot verifies RSA signature (Secure Boot)
  -> Verified OK -> boots kernel
  -> Invalid    -> boot REFUSED
         |
         +---> Slot Y boots OK?
               |
               YES -> boot-confirm resets bootcount=0
                   -> Slot Y becomes new active slot
               |
               NO  -> bootcount++ -> reboot
                   -> after 3 failures -> ROLLBACK to Slot X
```

---

## Dynamic Slot Targeting — Key Innovation

Before Phase 6, `sw-description` had `/dev/vda3` hardcoded — sending an OTA while on Slot B would overwrite the running system.

After Phase 6:

```
sw-description:  device = "/dev/target_slot"   (never hardcoded)

preinst.sh logic:
  if bootslot == "a":
    /dev/target_slot -> /dev/vda3  (Slot B, inactive)
    next bootslot = "b"
  else:
    /dev/target_slot -> /dev/vda2  (Slot A, inactive)
    next bootslot = "a"
```

This makes the pipeline truly bidirectional and infinite:

```
Slot A v1.0 -> OTA v2.0 -> Slot B v2.0 -> OTA v3.0 -> Slot A v3.0 -> ...
```

---

## Cloud OTA Pull Model — OTA Agent (Phase 7)

The cloud server lives in its own repository: **[Moez-La/ota-server](https://github.com/Moez-La/ota-server)** (FastAPI, deployed on Render). The OTA Agent in this repository (`meta-moez/recipes-app/ota-agent/`) is its client.

**OTA Agent behavior (started at boot by `boot-confirm`, logs in `/var/log/ota-agent.log`):**

1. Mounts a 200 MB tmpfs on `/ota` and kills any stray `swupdate` process.
2. Wakes the server with `/health` (Render free tier goes to sleep).
3. Reads the local version from `/var/lib/swupdate/ota-version`.
4. Polls `/version` every 60 seconds.
5. If the server version is newer, downloads `/firmware` to `/ota/update.swu`.
6. Checks the download size (> 1 MB).
7. Runs `swupdate -m -M -i /ota/update.swu -k /etc/swupdate/swupdate-public.pem -H qemuarm:1.0`.
8. SWUpdate verifies the RSA signature and installs on the inactive slot (same dynamic targeting as before).
9. Reboots into the new slot.

**Server endpoints:**

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Liveness check / wake-up |
| `GET /version` | Latest version, parsed from the uploaded `.swu`; anti-rollback (HTTP 409) |
| `GET /firmware` | Download the latest `.swu` (API key required) |
| `POST /upload` | Publish a new `.swu` (upload key required) |

**Anti-rollback:** uploading a version lower than or equal to the one on the server is rejected with HTTP 409.

**Why tmpfs + 512 MB RAM:** downloading to `/tmp`, `/var/volatile` or the rootfs failed with "Failed writing received data" (no space). A dedicated 200 MB tmpfs on `/ota` fixed it.

---

## Secure Boot — Chain of Trust

```
Mechanism   : U-Boot Verified Boot via signed FIT (Flattened Image Tree)
Algorithm   : RSA 2048-bit + SHA256
Private key : secureboot/keys/fit-private.key (gitignored)
Public key  : compiled into U-Boot control DTB at build time
```

```
Boot sequence:

U-Boot (RSA public key compiled in)
  -> loads kernel.itb from active slot
  -> ## Loading kernel from FIT Image at 44000000 ...
  ->    Using 'conf-1' configuration
  ->    Verifying Hash Integrity ... OK
  ->    Verifying Hash Integrity ... sha256+ OK
  -> Starting kernel ...
  -> Linux boots -> SWUpdate ready -> OTA pipeline active
```

Without Secure Boot, an attacker with physical access could replace the kernel directly on the partition. With Secure Boot, U-Boot refuses to execute any kernel whose RSA signature does not match the public key compiled into the bootloader binary.

---

## gateway-monitor — Dynamic Slot Detection

All three versions now read the active slot dynamically from `/proc/cmdline` instead of having it hardcoded in the C source:

```c
void get_slot() {
    FILE *fp = fopen("/proc/cmdline", "r");
    char buf[512];
    fgets(buf, sizeof(buf), fp);
    fclose(fp);
    if (strstr(buf, "vda2"))
        strcpy(active_slot, "A");
    else if (strstr(buf, "vda3"))
        strcpy(active_slot, "B");
}
```

**v3.0 new features:**
- Real-time bandwidth RX/TX (KB/s calculated over 1s window)
- Dropped packets monitoring from `/proc/net/dev`
- Active process count from `/proc`
- Adaptive health monitor based on CPU load thresholds

---

## Security Model

```
OTA package security:

1. OTA unsigned (no sw-description.sig)
   -> Rejected immediately by SWUpdate
   -> No installation, active slot untouched

2. OTA signed + corrupted image (valid RSA, empty ext4)
   -> Verified OK by RSA
   -> Installed on inactive slot
   -> Boot fails -> bootcount=1,2,3 -> ROLLBACK to previous slot

3. OTA signed + valid image
   -> Verified OK by RSA
   -> Installed on inactive slot
   -> Boot succeeds -> new slot active

Boot-time security (Secure Boot):

4. Kernel FIT image signature verification
   -> RSA public key embedded in U-Boot at build time
   -> Every boot: signature verified before kernel execution
   -> Tampered or unsigned kernel -> boot REFUSED

Cloud security (Phase 7):

5. Download protected by an API key; upload protected by a separate upload key
6. Anti-rollback: older or equal version rejected by the server (HTTP 409)
7. Every package downloaded by the agent is still RSA-verified by SWUpdate before install
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
- [x] Phase 4 — Clean SWUPDATE successful logs (via `-m -M` flags)
- [x] Phase 5 — U-Boot Secure Boot (FIT image RSA signature verification)
- [x] Phase 6 — Dynamic A/B slot targeting (preinst.sh + /dev/target_slot)
- [x] Phase 6 — gateway-monitor v3.0 (bandwidth, health, processes)
- [x] Phase 6 — Dynamic slot detection from /proc/cmdline in all versions
- [x] Phase 7 — C++ OTA Agent (libcurl) with autostart at boot
- [x] Phase 7 — FastAPI cloud OTA server on Render ([ota-server](https://github.com/Moez-La/ota-server))
- [x] Phase 7 — Pull-model OTA with dynamic version parsed from `.swu` and anti-rollback (HTTP 409)
- [ ] Next — mTLS with per-device certificates
- [ ] Next — Port to Raspberry Pi
- [x] Bonus — Remote OTA via internet from smartphone (ngrok integrated in run-qemu.sh)

---

## Known Limitations

- Render free tier sleeps and its filesystem is ephemeral — the `.swu` must be re-uploaded after a server restart (see [ota-server](https://github.com/Moez-La/ota-server)).
- `gateway-monitor` is not auto-started; only the OTA Agent starts at boot.
- The API keys in the demo code are shared demo values; production would use per-device credentials / mTLS.
- QEMU only (512 MB RAM); `postinstall.sh` currently writes a fixed version to the target slot's version file.

---

## Why This Project

Most junior embedded engineers know how to compile a kernel or build a rootfs. Far fewer understand how to **safely update** a deployed embedded system without risking a brick, and even fewer can build a **complete chain of trust** from bootloader to application with truly dynamic slot management.

This project implements the same OTA and Secure Boot architecture used in:
- Industrial IoT devices
- Automotive ECUs (SOTA updates, ISO 21434 cybersecurity)
- Defense and aerospace embedded systems (Thales, Airbus, Collins...)

---

## Build Results

### Phase 1 — Yocto Image (Completed)

```
Build system   : Yocto Project Scarthgap 5.0.18
Target         : QEMU ARM (qemuarm)
Kernel         : Linux 6.6.127-yocto-standard
Architecture   : ARMv7 Processor rev 0 (v7l)
Compiler       : arm-poky-linux-gnueabi-gcc 13.4.0
Tasks executed : 4060 tasks — 0 errors
```

---

### Phase 2 — Gateway Image with SWUpdate (Completed)

```
Image name     : gateway-image
Rootfs size    : 22 MB
Added packages : SWUpdate v2026.05, Dropbear SSH, iproute2, ethtool, procps
```

---

### Phase 3 — A/B OTA Pipeline (Completed)

```
Disk layout     : GPT 800MB — vda1 FAT 1MB + vda2 Slot A 400MB + vda3 Slot B 400MB
Boot script     : boot.scr loaded automatically by U-Boot bootcmd
Slot selection  : U-Boot reads bootslot from vda1 FAT (persistent)
```

---

### Phase 4 — Rollback + RSA Signing + CI/CD (Completed)

```
Rollback trigger : bootcount >= bootlimit (3 failed attempts)
Signing          : RSA 2048-bit + SHA256 — create-swu.sh via openssl dgst
CI/CD            : GitHub Actions — passing on every push
```

```
[INFO] : SWUPDATE started  : Software Update started !
[INFO] : SWUPDATE running  : Installation in progress
[INFO] : SWUPDATE successful ! SWUPDATE successful !
```

---

### Phase 5 — U-Boot Secure Boot (Completed)

```
Mechanism   : U-Boot Verified Boot via signed FIT image
Algorithm   : RSA 2048-bit + SHA256
Kconfig     : CONFIG_FIT_SIGNATURE=y, CONFIG_RSA=y, CONFIG_RSA_VERIFY=y
Public key  : compiled into U-Boot control DTB (qemu-arm-pubkey.dtsi)
```

```
   Verifying Hash Integrity ... OK
   Verifying Hash Integrity ... sha256+ OK
Starting kernel ...
qemuarm login: root
```

---

### Phase 6 — Dynamic A/B Slot Targeting (Completed)

```
preinst.sh    : reads active slot from vda1 FAT, creates /dev/target_slot symlink
postinstall.sh: re-reads vda1 FAT, writes opposite bootslot, creates uboot.env on target
sw-description: device = "/dev/target_slot" — never hardcoded
```

```
Validated pipeline:
Slot A v1.0 -> OTA v2.0 -> Slot B v2.0 -> OTA v3.0 -> Slot A v3.0
Bidirectional — infinite — always installs on inactive slot
```

```
gateway-monitor v3.0 (Slot A — dynamic):
  Version  : 3.0.0
  Slot     : A (from /proc/cmdline)
  Bandwidth RX : 0.00 KB/s
  Dropped pkts : RX=0 TX=0
  Processes    : 67 active
  Health       : NOMINAL - OPTIMAL
```

---

### Phase 7 — Cloud OTA Pull Model (Completed)

```
Agent          : C++17 + libcurl, polls every 60 s, log /var/log/ota-agent.log
Server         : FastAPI on Render (Moez-La/ota-server)
Download area  : 200 MB tmpfs on /ota (QEMU RAM 512 MB)
Install        : swupdate -m -M ... -> "SWUPDATE successful" on v1 -> v2.0.0
Anti-rollback  : lower/equal version rejected with HTTP 409
```

---

### Bonus — Remote OTA via Internet (Completed)

```
Tool     : ngrok (integrated in run-qemu.sh)
Test     : OTA sent from smartphone on 4G — different network
Security : RSA signature ensures only authorized .swu are accepted
```

---

## Author

**Moez Chagraoui** — Embedded Systems Engineer  
Double degree: INP-ENSEEIHT Toulouse (ACISE) + ENIT Tunis  
[LinkedIn](https://linkedin.com/in/moezchagraoui) • [GitHub](https://github.com/Moez-La) • [OTA Server repo](https://github.com/Moez-La/ota-server)
