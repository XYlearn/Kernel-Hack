#!bash

RELEASE=full

curl -s https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh \
  | sed "s/syzkaller/XYlearn/" 
  | bash -s -- --distribution $RELEASE --seek 4096
exit
# Move to images
SCRIPT_DIR=$(dirname $0)
ROOT="$SCRIPT_DIR/.."
sudo mv $RELEASE.img $ROOT/images/disk.img
sudo mv $RELEASE.id_rsa $ROOT/images/ssh.id_rsa
sudo mv $RELEASE.id_rsa.pub $ROOT/images/ssh.id_rsa.pub
