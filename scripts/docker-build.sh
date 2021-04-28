#!/bin/sh

DOCKER_DIR=`dirname $0`/../dockers
docker rmi xylearn/kernel-hack > /dev/null 2>&1
docker build -t xylearn/kernel-hack $DOCKER_DIR
