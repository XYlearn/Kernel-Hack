#!/bin/bash

ROOT=`realpath $(dirname $0)/..`
IMAGE_DIR=$ROOT/images
SOURCE_DIR=$ROOT/sources

if [[ $# != 1 ]]; then
  echo "Usage: $0 IDENTIFIER"
  exit
fi

IDEN=$1

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}


pushd "$SOURCE_DIR/$IDEN"

# Configuration
make defconfig
make kvmconfig
cat << EOF >> .config
# Coverage collection.
CONFIG_KCOV=y

# Debug info for symbolization.
CONFIG_DEBUG_INFO=y

# Memory bug detector
CONFIG_KASAN=y
CONFIG_KASAN_INLINE=y

# Required for Debian Stretch
CONFIG_CONFIGFS_FS=y
CONFIG_SECURITYFS=y
EOF
make olddefconfig

# Build image
make -j8 && cp arch/x86_64/boot/bzImage $IMAGE_DIR/$IDEN.img

# Build modules
INSTALL_MOD_PATH=$IMAGE_DIR/modules-$IDEN
mkdir -p $INSTALL_MOD_PATH
make modules_install INSTALL_MOD_PATH=$INSTALL_MOD_PATH

popd
