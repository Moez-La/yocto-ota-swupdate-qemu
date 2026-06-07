# yocto-ota-swupdate-qemu

![Status](https://img.shields.io/badge/status-in%20progress-yellow)
![Platform](https://img.shields.io/badge/platform-QEMU%20ARM-blue)
![Build](https://img.shields.io/badge/build%20system-Yocto%20Scarthgap-green)

Embedded Linux image built with **Yocto Project (Scarthgap)** for QEMU ARM — featuring a complete OTA (Over-The-Air) update pipeline with **SWUpdate** and **A/B partition scheme** with automatic rollback via **U-Boot**.

---

## Overview

This project demonstrates a production-ready embedded Linux update mechanism — the kind used in industrial equipment, automotive systems, and defense electronics deployed in the field.

The system can receive a software update remotely, install it safely on a secondary partition, and automatically roll back to the previous version if the new one fails to boot.

---

## Architecture

```
+--------------------------------------------------+
|                    QEMU ARM                      |
|                                                  |
|  +-----------+  +-------------+  +------------+  |
|  |  U-Boot   |  |   Slot A    |  |   Slot B   |  |
|  | bootloader|  | Linux v1.0  |  | Linux v2.0 |  |
|  |           |  |  (active)   |  |  (update)  |  |
|  +-----------+  +-------------+  +------------+  |
|       |                                          |
|       +-- selects active slot + manages rollback |
|                                                  |
|  +----------------------------------------------+|
|  |  SWUpdate daemon                             ||
|  |  - receives .swu update package              ||
|  |  - verifies integrity                        ||
|  |  - writes to inactive slot                   ||
|  |  - notifies U-Boot for next boot             ||
|  +----------------------------------------------+|
+--------------------------------------------------+
```

---

## Stack

| Component        | Details                        |
|------------------|--------------------------------|
| Build system     | Yocto Project — Scarthgap 5.0  |
| Target machine   | QEMU ARM (qemuarm)             |
| Bootloader       | U-Boot                         |
| Update manager   | SWUpdate                       |
| Partition scheme | A/B dual partition with rollback|
| Architecture     | ARMv7 (Cortex-A15)             |
| Host OS          | Ubuntu 22.04 LTS               |

---

## Project Structure

```
yocto-ota-swupdate-qemu/
├── poky/                    → Yocto Poky base (Scarthgap)
├── meta-swupdate/           → SWUpdate layer (coming)
├── meta-moez/               → Custom layer (coming)
│   ├── recipes-core/        → Custom image recipe
│   ├── recipes-swupdate/    → SWUpdate configuration
│   └── recipes-app/         → Demo application
├── build/
│   └── conf/
│       ├── local.conf       → Build configuration
│       └── bblayers.conf    → Active layers
└── docs/
    └── guide.md             → Step-by-step build guide
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
- [ ] Phase 2 — Add meta-swupdate layer
- [ ] Phase 2 — Configure U-Boot A/B partition scheme
- [ ] Phase 3 — Build and test OTA update pipeline
- [ ] Phase 3 — Validate automatic rollback mechanism
- [ ] Phase 4 — CI/CD pipeline + full documentation

---

## Why This Project

Most junior embedded engineers know how to compile a kernel or build a rootfs. Far fewer understand how to **safely update** a deployed embedded system without risking a brick.

This project implements the same OTA architecture used in:
- Industrial IoT devices
- Automotive ECUs (SOTA updates)
- Defense and aerospace embedded systems (Thales, Airbus, Collins...)

---

## Author

**Moez Chagraoui** — Embedded Systems Engineer  
Double degree: INP-ENSEEIHT Toulouse (ACISE) + ENIT Tunis  
[LinkedIn](https://linkedin.com/in/moez-chagraoui) • [GitHub](https://github.com/Moez-La)
