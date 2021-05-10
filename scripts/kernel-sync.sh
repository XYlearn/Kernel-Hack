#!/bin/bash

# Currently this command only send file or directory to remote
if [[ $# < 1 ]]; then
  echo "Usage: $0 SRC [DST]"
  exit
fi

SOURCE=$1
DEST=$2

if [[ -d $SOURCE ]]; then
  BASENAME=`basename $SOURCE`
  cd $SOURCE && tar cf - . | kernel-ssh "cd $DEST && tar xf -"
elif [[ -f $SOURCE ]]; then
  SOURCE_DIR=`dirname $SOURCE`
  SOURCE_BASE=`basename $SOURCE`
  cd $SOURCE_DIR && tar cf - $SOURCE_BASE | kernel-ssh "cd $DEST && tar xf -"
else
  echo "[-] Source file/directory $SOURCE doesn't exist!"
  exit
fi