# Kernel-Hack
My scripts for kernel hacking

## Scripts Introduction

```
scripts                         
├── disk-build.sh            # build a debian filesystem image
├── docker-build.sh          # build a docker for kernel building
|                            # on Windows/MacOS
├── docker-run.sh            # run the docker
├── kernel-build.sh          # build kernel
├── kernel-module-install.sh # install module into the running 
|                            # kernel filesystem
├── kernel-run.sh            # run built kernel on the debian filesystem
├── kernel-sftp.sh           # sftp to running kernel
├── kernel-source-prepare.sh # download and extract source code 
|                            # of kernel
└── kernel-ssh.sh            # ssh to running kernel

dockers
├── Dockerfile      # Dockerfile for kernel building container on 
|                   # Windows/MacOS
└── Dockerfile.work # Dockerfile for working container, it can be   
                    # modified for incremental customization
```


## Workflow

Note: IDEN below is either a tag like `v4.14` or a commit number like `acd3d28594536e9096c1ea76c5867d8a68babef6`, which specifies the kernel version.


### (Optional) Building & Running docker
Not necessary on Linux, because docker is used for building kernel.
First build docker with
```bash
scripts/docker-build.sh
```
This will create a docker image, which is needed for kernel building in MacOS/Windows.

Then run the docker with
```bash
scripts/docker-run.sh
```
This will create a docker image for work, run a container on it (which will be removed when exiting), and spawn a shell.


### Build Disk Image
The following script will create a filesystem image for qemu emulation under `images`.
```
scripts/disk-build.sh
```
If you work on linux, you can directly run this script, However you should preinstall some requirement package. See [Syzkaller document](https://github.com/google/syzkaller/blob/master/docs/linux/setup_ubuntu-host_qemu-vm_x86-64-kernel.md).


### Prepare & Build Kernel Source
First
```
scripts/kernel-source-prepare.sh IDEN
```
This will download kernel source of version specified by IDEN to `downloads` directory. And then the downloaded source code will be extracted to `sources` directory.

Then build kernel with following script
```
scripts/kernel-build.sh IDEN
```
Note that, MacOS/Windows should execute this script in docker shell described above. Linux should either install the essential tools or use the docker for building.

This will build a kernel image. The building process can be modified for different purposes.


### Run Kernel with QEMU
First you should install [QEMU](https://www.qemu.org).
Then run kernel with 
```
scripts/kernel-run.sh
```
The kernel will boot, and spawn a login shell. Then you can start hacking. 

**Note that** the script uses `hvf` for acceleration, which should be modified according to your case. You can run `qemu-system-x86_64 -accel help` to see acceleration that can be used. For example if `kvm` is in the output, you can adopt kvm acceleration by changing `-accel hvf` to `-accel kvm` in the script.


### (Optional) Install Modules
You can install modules to the running qemu instance to safely use kernel module functionalities by running
```
scripts/kernel-module-install.sh
```


### (Optional) Using SSH Utilities
You can ssh to the running qemu instance with
```
scripts/kernel-ssh.sh
```
or sftp to int with
```
scripts/kernel-sftp.sh
``` 
