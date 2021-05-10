#!/bin/bash
ROOT=`realpath $(dirname $0)/..`
DOCKER_DIR=$ROOT/dockers

if [[ $# == 0 ]]; then
  DOCKER_TAG=work
else
  DOCKER_TAG=$1
fi

# S_IMAGE=xylearn/kernel-hack
IMAGE=xylearn/kernel-hack:$DOCKER_TAG
CONTAINER=kernel-hack-$DOCKER_TAG

DOCKER_FILE="$DOCKER_DIR/Dockerfile.$DOCKER_TAG"
if [[ ! -f $DOCKER_FILE ]]; then
  echo "File $DOCKER_FILE not exist"
  exit -1
fi

# rebuild with new directory files

docker rm "$CONTAINER" > /dev/null 2>&1
docker rmi "$IMAGE" > /dev/null 2>&1
docker build -t "$IMAGE" -f "$DOCKER_FILE" "$ROOT" && \
docker run --rm -it --privileged --security-opt seccomp=unconfined -v "$ROOT:/root/o" -v "/Volumes/sources:/Volumes/sources" --name "$CONTAINER" "$IMAGE"
