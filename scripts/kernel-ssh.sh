#!/bin/bash

ROOT=$(dirname $0)/..
ssh -i $ROOT/images/ssh.id_rsa -p 10021 -o "StrictHostKeyChecking no" root@localhost
