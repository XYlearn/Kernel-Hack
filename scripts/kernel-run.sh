#!/bin/bash

SCRIPT_DIR=$(dirname $0)

if [[ $# != 1 ]]; then
  echo "Usage: $0 IDENTIFIER"
  exit
fi

IDEN=$1

ROOT="$SCRIPT_DIR/.."
if [[ -d $ROOT/o ]]; then
  IMAGE_DIR=$ROOT/o/images
else
  IMAGE_DIR=$ROOT/images
fi

qemu-system-x86_64 \
	-m 2G \
	-smp 2 \
	-kernel $IMAGE_DIR/$IDEN.img \
	-append "console=ttyS0 root=/dev/sda earlyprintk=serial net.ifnames=0" \
	-drive file=$IMAGE_DIR/disk.img,format=raw \
	-net user,host=10.0.2.10,hostfwd=tcp:127.0.0.1:10021-:22 \
	-net nic,model=e1000 \
  -accel hvf \
	-nographic \
	-pidfile vm.pid \
	2>&1 | tee vm.log