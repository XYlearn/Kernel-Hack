#!/bin/bash

RELEASE=stretch

SCRIPT_DIR=$(dirname $0)
ROOT="$SCRIPT_DIR/.."

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

TEMPDIR=`mktemp -d`

pushd $TEMPDIR

curl -s https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh \
  | sed "s/syzkaller/XYlearn/" \
  | bash -s -- --distribution $RELEASE --seek 8096 # leave 8 GB

# Move to images
sudo mv $RELEASE.img $ROOT/images/disk.img
sudo mv $RELEASE.id_rsa $ROOT/images/ssh.id_rsa
sudo mv $RELEASE.id_rsa.pub $ROOT/images/ssh.id_rsa.pub

popd

rm -r $TEMPDIR