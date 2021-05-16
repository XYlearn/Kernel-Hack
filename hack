#!/bin/bash

ROOT=`realpath $(dirname $BASH_SOURCE)`
# SCRIPT_DIR=$ROOT/scripts
IMAGE_DIR=$ROOT/images
DOWNLOAD_DIR=$ROOT/downloads
SOURCE_DIR=$ROOT/sources
DOCKER_DIR=$ROOT/dockers

#################################
# Utilities
#################################

pushd () {
	command pushd "$@" > /dev/null
}

popd () {
	command popd "$@" > /dev/null
}

unzip-strip () (
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

prepare-directories () {
	mkdir -p $IMAGE_DIR $DOWNLOAD_DIR

	# Create directory, only considering macos and linux
	platform='unknown'
	unamestr=`uname`
	if [[ "$unamestr" == 'Darwin' ]]; then
		# If on macos, the directory should be created with a case sensitive image
		IMAGE=$ROOT/sources.sparseimage
		if [[ ! -e $IMAGE ]]; then
			hdiutil create -type SPARSE -fs 'Case-sensitive Journaled HFS+' -size 100g -volname sources $IMAGE
		fi
		if [[ ! -h $SOURCE_DIR ]]; then
			ln -s /Volumes/sources $SOURCE_DIR
		fi
		hdiutil attach $IMAGE >/dev/null 2>&1
	else
		# Just create a directory
		mkdir -p $SOURCE_DIR
	fi
}

my-download () {
	if [[ $# != 2 ]]; then
		echo "Internal error: download $@"
		return 1
	fi

	URL=$1
	TARGET=$2
	wget $URL -q --show-progress -P "$DOWNLOAD_DIR" -O $TARGET
	STATUS=$?
	if [[ $STATUS -ne 0 ]]; then
		echo "[-] Fail to download from $URL"
		rm $TARGET
	else
		echo "[+] Download success from $URL"
	fi
	return $STATUS
}

#################################
# disk subcommand
#################################

disk-build () {
	RELEASE=stretch
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
}

disk-resize () {
	if [[ $# != 1 ]]; then
		echo "Usage $0 $SUBCOMMAND SIZE"
		echo "  SIZE: Gigabytes number"
	fi

	GIGA=$1
	NEW_SIZE=$(($GIGA*1024))
	if [[ $NEW_SIZE -le 0 ]]; then
		echo "Invalid size '$GIGA'. It must be a positive number."
		exit
	fi

	CMD="resize2fs $IMAGE_DIR/disk.img ${NEW_SIZE}M"
	echo $CMD
	read -p "Are you sure?(y/N) " -n 1 -r
	echo    # (optional) move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		$CMD
	else
		echo "Abort"
	fi
}


#################################
# docker subcommand
#################################

docker-build () {
	docker rmi xylearn/kernel-hack > /dev/null 2>&1
	docker build -t xylearn/kernel-hack $DOCKER_DIR
}

docker-run () {
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

	docker rm "$CONTAINER" > /dev/null 2>&1
	docker rmi "$IMAGE" > /dev/null 2>&1
	docker build -t "$IMAGE" -f "$DOCKER_FILE" "$ROOT" && \
	docker run --rm -it --privileged --security-opt seccomp=unconfined -v "$ROOT:/root/o" -v "/Volumes/sources:/Volumes/sources" --name "$CONTAINER" "$IMAGE"
}


#################################
# kernel subcommand
#################################

kernel-source-prepare () {
	if [[ $# != 1 ]]; then
		echo "Usage: $0 $SUBCOMMAND IDENTIFIER"
		exit
	fi

	IDEN=$1
	NAME=linux-$IDEN

	# Download zip
	if [[ ! -f "$DOWNLOAD_DIR/$NAME.zip" ]];then
		if [[ $IDEN =~ ^v[0-9\.-]+((rc[0-9]+)|(tree))?$ ]]; then
			# Tag
			URL="https://github.com/torvalds/linux/archive/refs/tags/$IDEN.zip"
		else
			# Commit number
			URL="https://github.com/torvalds/linux/archive/$IDEN.zip"
		fi
		
		my-download $URL $DOWNLOAD_DIR/$NAME.zip
		if [[ $? -ne 0 ]]; then
			exit
		fi
	fi

	# Extract zip
	TARGET_ROOT="$SOURCE_DIR/$NAME"
	if [[ ! -d $TARGET_ROOT ]]; then
		mkdir -p $TARGET_ROOT
		unzip-strip "$DOWNLOAD_DIR/$NAME.zip" $TARGET_ROOT
	fi
}

kernel-build () {
	if [[ $# < 1 ]]; then
		echo "Usage: $0 $SUBCOMMAND [-j threads] IDENTIFIER"
		exit
	fi

	while :; do
		case $1 in
			-j)
				THREADS=$2
				shift
				shift
				;;
			*)
				break
				;;
		esac
	done

	IDEN=$1
	NAME=linux-$IDEN

	if [[ ! -d $SOURCE_DIR/$NAME ]]; then
		echo "Invalid argument '$IDEN' or the source is not prepared. Try download it with '$0 kernel-source-prepare $IDEN'"
		exit
	fi

	pushd "$SOURCE_DIR/$NAME"

	# Configuration
	make defconfig
	make kvmconfig
	cat << EOF >> .config
# Coverage collection.
CONFIG_KCOV=y

# Debug info for symbolization.
CONFIG_DEBUG_INFO=y

# Memory bug detector
CONFIG_KASAN=y
CONFIG_KASAN_INLINE=y

# Required for Debian Stretch
CONFIG_CONFIGFS_FS=y
CONFIG_SECURITYFS=y

# Enable eBPF

CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
# [optional, for tc filters]
CONFIG_NET_CLS_BPF=m
# [optional, for tc actions]
CONFIG_NET_ACT_BPF=m
CONFIG_BPF_JIT=y
# [for Linux kernel versions 4.1 through 4.6]
CONFIG_HAVE_BPF_JIT=y
# [for Linux kernel versions 4.7 and later]
CONFIG_HAVE_EBPF_JIT=y
# [optional, for kprobes]
CONFIG_BPF_EVENTS=y

## There are a few optional kernel flags needed for running bcc networking examples on vanilla kernel:

CONFIG_NET_SCH_SFQ=m
CONFIG_NET_ACT_POLICE=m
CONFIG_NET_ACT_GACT=m
CONFIG_DUMMY=m
CONFIG_VXLAN=m
EOF
	make olddefconfig

	# Build image
	make -j8 && cp arch/x86_64/boot/bzImage $IMAGE_DIR/$NAME.img

	# Build modules
	INSTALL_MOD_PATH=$IMAGE_DIR/modules-$NAME
	mkdir -p $INSTALL_MOD_PATH
	make modules_install INSTALL_MOD_PATH=$INSTALL_MOD_PATH

	popd
}

kernel-run () {
	if [[ $# != 1 ]]; then
		echo "Usage: $0 $SUBCOMMAND IDENTIFIER"
		exit
	fi

	IDEN=$1
	NAME=linux-$IDEN

	if [[ -d $ROOT/o ]]; then
		IMAGE_DIR=$ROOT/o/images
	else
		IMAGE_DIR=$ROOT/images
	fi

	unamestr=`uname`
	if [[ "$unamestr" == 'Darwin' ]]; then
		DEFAULT_ACCEL=hvf
	else
		DEFAULT_ACCEL=kvm
	fi

	qemu-system-x86_64 \
		-m 2G \
		-smp 2 \
		-kernel $IMAGE_DIR/$NAME.img \
		-append "console=ttyS0 root=/dev/sda earlyprintk=serial net.ifnames=0" \
		-drive file=$IMAGE_DIR/disk.img,format=raw \
		-net user,host=10.0.2.10,hostfwd=tcp:127.0.0.1:10021-:22 \
		-net nic,model=e1000 \
		-accel $DEFAULT_ACCEL \
		-nographic \
		-pidfile vm.pid \
		2>&1 | tee vm.log
}

_kernel-host() {
	# get host of 
	if nc -zv localhost 10021 >/dev/null 2>&1; then
		echo "localhost"
		return
	fi

	if nc -zv host.docker.internal 10021 >/dev/null 2>&1; then
		# docker to host
		echo "host.docker.internal"
		return
	else
		return 
	fi
}

kernel-ssh () {
	if [[ ! -f $ROOT/images/ssh.id_rsa ]]; then
		echo "Please run kernel with disk image created with this script"
		exit
	fi

	ssh -i $ROOT/images/ssh.id_rsa -p 10021 -o "StrictHostKeyChecking no" root@`_kernel-host` "$@"
}

kernel-sftp () {
	if [[ ! -f $ROOT/images/ssh.id_rsa ]]; then
		echo "Please run kernel with disk image created with this script"
		exit
	fi
	sftp -i $ROOT/images/ssh.id_rsa -P 10021 -o "StrictHostKeyChecking no" root@`_kernel-host`
}

kernel-sync () {
	# Currently this command only send file or directory to remote
	if [[ $# < 1 ]]; then
		echo "Usage: $0 $SUBCOMMAND SRC [DST]"
		exit
	fi

	SOURCE=$1
	DEST=$2

	if [[ -e $SOURCE ]]; then
		SOURCE_DIR=`dirname $SOURCE`
		SOURCE_BASE=`basename $SOURCE`
		cd $SOURCE_DIR && tar cf - $SOURCE_BASE | kernel-ssh "cd $DEST && tar xf -"
	else
		echo "[-] Source file/directory $SOURCE doesn't exist!"
		exit
	fi
}

kernel-module-install () {
	if [[ $# != 1 ]]; then
		echo "Usage: $0 $SUBCOMMAND IDENTIFIER"
		exit
	fi

	IDEN=$1
	NAME=linux-$IDEN
	SOURCE=$ROOT/images/modules-$IDEN/lib

	if [[ ! -d $SOURCE ]];then
		echo "Build kernel for $IDEN first with '$0 kernel-build $IDEN'"
		exit -1
	fi

	cd $SOURCE/.. && tar cf - lib | kernel-ssh 'cd / && tar xf -'
	kernel-ssh 'cd /lib/modules/* && unlink build && unlink source && mkdir source && ln -s ./source ./build'
	cd $ROOT/sources/$NAME && tar cf - . | kernel-ssh 'cd /lib/modules/*/source && tar xf -'
}


#################################
# llvm subcommand
#################################

llvm-source-prepare () {
	if [[ $# != 1 ]]; then
		echo "Usage: $0 $SUBCOMMAND TAG"
		exit
	fi

	TAG=$1

	LLVM_SOURCE_TAR="llvm-$TAG.src.tar.xz"
	CLANG_SOURCE_TAR="clang-$TAG.src.tar.xz"
	LLVM_SOURCE_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-$TAG/$LLVM_SOURCE_TAR"
	CLANG_SOURCE_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-$TAG/$CLANG_SOURCE_TAR"

	if [[ ! -e $DOWNLOAD_DIR/$LLVM_SOURCE_TAR ]]; then
		my-download $LLVM_SOURCE_URL $DOWNLOAD_DIR/$LLVM_SOURCE_TAR || exit
	fi

	if [[ ! -e $DOWNLOAD_DIR/$CLANG_SOURCE_TAR ]]; then
		my-download $CLANG_SOURCE_URL $DOWNLOAD_DIR/$CLANG_SOURCE_TAR || exit
	fi

	LLVM_SOURCE=llvm-$TAG.src
	CLANG_SOURCE=clang-$TAG.src
	if [[ ! -e $SOURCE_DIR/$LLVM_SOURCE ]]; then
		tar xf $DOWNLOAD_DIR/$LLVM_SOURCE_TAR -C $SOURCE_DIR || exit
	fi
	
	if [[ ! -e $SOURCE_DIR/$LLVM_SOURCE ]]; then
		tar xf $DOWNLOAD_DIR/$CLANG_SOURCE_TAR -C $SOURCE_DIR && mv $SOURCE_DIR/$CLANG_SOURCE $SOURCE_DIR/$LLVM_SOURCE/tools/clang || exit
	fi
}

llvm-build () {
	if [[ $# != 1 ]]; then
		echo "Usage: $0 $SUBCOMMAND TAG"
		exit
	fi

	TAG=$1
	llvm-source-prepare $TAG

	LLVM_SOURCE_DIR=$SOURCE_DIR/llvm-$TAG.src
	
	BUILD_DIR=$LLVM_SOURCE_DIR/_build
	mkdir -p $BUILD_DIR
	pushd $BUILD_DIR
	cmake -G "Unix Makefiles" --enable-optimized --enable-targets=host-only  -DCMAKE_BUILD_TYPE=Release  .. && \
	make -j8
	# sudo make install
	popd
}


#################################
# Argument parsing
#################################

usage () {
	echo "$0 Command [Args ...]"
	echo "Avaiable commands:"
	echo "  disk-build            : build a debian filesystem image"
	echo "  disk-resize           : resize the created filesystem image"
	echo "  docker-build          : build a docker for kernel building"
	echo "  docker-run            : run the built docker"
	echo "  kernel-source-prepare : download and extract source code of kernel"
	echo "  kernel-build          : build kernel"
	echo "  kernel-run            : run the docker"
	echo "  kernel-ssh            : ssh to running kernel"
	echo "  kernel-sftp           : sftp to running kernel"
	echo "  kernel-sync           : send files to running kernel"
	echo "  kernel-module-install : install module into the running kernel"
	echo "  llvm-source-prepare   : download and extract source code of llvm+clang"
	echo "  llvm-build            : build llvm+clang from source"
}

prepare-directories

POSITIONAL=()
if [[ $# == 0 ]]; then
	usage
	exit
fi

SUBCOMMAND=$1
shift
case $SUBCOMMAND in
	disk-build)
		disk-build $@
		;;
	disk-resize)
		disk-resize $@
		;;
	docker-build)
		docker-build $@
		;;
	docker-run)
		docker-run $@
		;;
	kernel-source-prepare)
		kernel-source-prepare $@
		;;
	kernel-build)
		kernel-build $@
		;;
	kernel-run)
		kernel-run $@
		;;
	kernel-ssh)
		kernel-ssh $@
		;;
	kernel-sftp)
		kernel-sftp $@
		;;
	kernel-sync)
		kernel-sync $@
		;;
	kernel-module-install)
		kernel-module-install $@
		;;
	llvm-source-prepare)
		llvm-source-prepare $@
		;;
	llvm-build)
		llvm-build $@
		;;
	*)
		usage
		;;
esac
