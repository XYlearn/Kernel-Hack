#!/bin/bash
ROOT="$(dirname $0)/.."
IMAGE_DIR=$ROOT/images

if [[ $# != 1 ]]; then
  echo "Usage: $0 IDENTIFIER TARGETDIR"
  exit
fi

IDEN=$1
SOURCE=$ROOT/images/modules-$IDEN/lib
echo $SOURCE
# ssh -i $ROOT/images/ssh.id_rsa -p 10021 -o "StrictHostKeyChecking no" root@localhost "if [[ -e $TARGETDIR ]] rm -r $TARGETDIR"
# scp -i $ROOT/images/ssh.id_rsa -P 10021 -o "StrictHostKeyChecking no" -r $SOURCE root@localhost:/