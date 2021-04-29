#!/bin/bash
ROOT=`realpath $(dirname $0)/..`
IMAGE_DIR=$ROOT/images

if [[ $# != 1 ]]; then
  echo "Usage: $0 IDENTIFIER"
  exit
fi

IDEN=$1
SOURCE=$ROOT/images/modules-$IDEN/lib

if [[ ! -d $SOURCE ]];then
  echo "Build kernel for $IDEN first"
  exit -1
fi

ssh_execute() {
  ssh -i $ROOT/images/ssh.id_rsa -p 10021 -o "StrictHostKeyChecking no" root@localhost "$@"
}

cd $SOURCE/.. && tar cf - lib | ssh_execute 'cd / && tar xf -'
ssh_execute 'unlink /lib/modules/*/build /lib/modules/*/source'