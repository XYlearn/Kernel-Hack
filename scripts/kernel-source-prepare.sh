#!/bin/bash

ROOT="$(dirname $0)/.."
DOWNLOAD_DIR=$ROOT/downloads
SOURCE_DIR=$ROOT/sources


if [[ $# != 1 ]]; then
  echo "Usage: $0 IDENTIFIER"
  exit
fi

IDEN=$1

# Create sources directory, only macos and linux
platform='unknown'
unamestr=`uname`
if [[ "$unamestr" == 'Darwin' ]]; then
  # If on macos, the directory should be created with a case sensitive image
  IMAGE=$ROOT/sources.sparseimage
  if [[ ! -e $IMAGE ]]; then
    hdiutil create -type SPARSE -fs 'Case-sensitive Journaled HFS+' -size 100g -volname sources $IMAGE
  fi
  hdiutil attach $IMAGE
else
  # Just create a directory
  if [[ ! -d $ROOT/sources ]]; then
    mkdir -p $ROOT/sources
  fi
fi

# Download zip

if [[ ! -f "$DOWNLOAD_DIR/$IDEN.zip" ]];then
  if [[ $IDEN =~ ^v[0-9\.-]+((rc[0-9]+)|(tree))?$ ]]; then
    # Tag
    URL="https://github.com/torvalds/linux/archive/refs/tags/$IDEN.zip"
  else
    # Commit number
    URL="https://github.com/torvalds/linux/archive/$IDEN.zip"
  fi
  
  wget_success=`wget $URL -q --show-progress -P "$DOWNLOAD_DIR"`
  if [[ $? -ne 0 ]]; then
    echo "[-] Fail to download from $URL"
    exit 1
  else
    echo "[+] Download success from $URL"
  fi
fi

# Extract zip

unzip-strip() (
  # From https://superuser.com/questions/518347/equivalent-to-tars-strip-components-1-in-unzip
  set -eu
  local archive=$1
  local destdir=${2:-}
  shift; shift || :
  local tmpdir=$(mktemp -d)
  trap 'rm -rf -- "$tmpdir"' EXIT
  unzip -qd "$tmpdir" -- "$archive"
  shopt -s dotglob
  local files=("$tmpdir"/*) name i=1
  if (( ${#files[@]} == 1 )) && [[ -d "${files[0]}" ]]; then
      name=$(basename "${files[0]}")
      files=("$tmpdir"/*/*)
  else
      name=$(basename "$archive"); name=${archive%.*}
      files=("$tmpdir"/*)
  fi
  if [[ -z "$destdir" ]]; then
      destdir=./"$name"
  fi
  while [[ -f "$destdir" ]]; do destdir=${destdir}-$((i++)); done
  mkdir -p "$destdir"
  cp -ar "$@" -t "$destdir" -- "${files[@]}"
)

TARGET_ROOT="$SOURCE_DIR/$IDEN"
if [[ ! -d $TARGET_ROOT ]]; then
  mkdir -p $TARGET_ROOT
  unzip-strip "$DOWNLOAD_DIR/$IDEN.zip" $TARGET_ROOT
fi
