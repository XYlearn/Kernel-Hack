#!/bin/sh
ROOT=`realpath $(dirname $0)/..`
DOCKER_DIR=$ROOT/dockers

# S_IMAGE=xylearn/kernel-hack
IMAGE=xylearn/kernel-hack:work
CONTAINER=kernel-hack-work

# rebuild with new directory files

docker rm $CONTAINER > /dev/null 2>&1
docker rmi $IMAGE > /dev/null 2>&1
docker build --quiet -t $IMAGE -f $DOCKER_DIR/Dockerfile.work $ROOT
docker run --rm -it --privileged --security-opt seccomp=unconfined -v "$ROOT:/root/o" -v "/Volumes/sources:/Volumes/sources" --name "$CONTAINER" $IMAGE
