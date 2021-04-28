#!/bin/bash
ROOT="$(dirname $0)/.."
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

scp -i $ROOT/images/ssh.id_rsa -P 10021 -o "StrictHostKeyChecking no" -prq $SOURCE root@localhost:/