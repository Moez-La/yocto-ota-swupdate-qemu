#!/bin/bash
# Setup script for yocto-ota-swupdate-qemu
# Clones all required layers and initializes the build environment

set -e

PROJ_DIR=$(dirname $(realpath $0))/..

echo "=== Cloning Yocto Poky (Scarthgap) ==="
git clone -b scarthgap https://git.yoctoproject.org/poky.git $PROJ_DIR/poky

echo "=== Cloning meta-openembedded ==="
git clone -b scarthgap https://github.com/openembedded/meta-openembedded.git $PROJ_DIR/meta-openembedded

echo "=== Cloning meta-swupdate ==="
git clone -b scarthgap https://github.com/sbabic/meta-swupdate.git $PROJ_DIR/meta-swupdate

echo "=== Initializing build environment ==="
source $PROJ_DIR/poky/oe-init-build-env $PROJ_DIR/build

echo ""
echo "=== Setup complete! ==="
echo "Run: bitbake gateway-image"
