#!/bin/bash

ROOT=$(dirname $0)/..
sftp -i $ROOT/images/ssh.id_rsa -P 10021 -o "StrictHostKeyChecking no" root@localhost
