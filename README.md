# Kernel-Hack
My scripts for kernel hacking

## Tree

The core files are listed below

```
.
├── hack                # manager script
└── dockers
    ├── Dockerfile      # Dockerfile for kernel building container on 
    |                   # Windows/MacOS
    └── Dockerfile.work # Dockerfile for working container, it can be   
                    # modified for incremental customization
```

---

## Workflow

Note: IDEN below is either a tag like `v4.14` or a commit number like `acd3d28594536e9096c1ea76c5867d8a68babef6`, which specifies the kernel version.


### 1. (Optional) Building & Running docker
Not necessary on Linux, because docker is used for building kernel.
First build docker with
```bash
./hack docker-build
```
This will create a docker image, which is needed for kernel building in MacOS/Windows.

Then run the docker with
```bash
./hack docker-run
```
This will create a docker image for work, run a container on it (which will be removed when exiting), and spawn a shell.


### Build Disk Image
The following script will create a filesystem image for qemu emulation under `images`.
```
./hack disk-build
```
If you work on Linux, you can directly run this script, However you should preinstall some requirement package. See [Syzkaller document](https://github.com/google/syzkaller/blob/master/docs/linux/setup_ubuntu-host_qemu-vm_x86-64-kernel.md).

If you work on Windows or MacOS, you'd better run this script in docker shell.


### Prepare & Build Kernel Source
First run the following script
```
./hack kernel-source-prepare IDEN
```
This will download kernel source of version specified by IDEN to `downloads` directory. And then the downloaded source code will be extracted to `sources` directory.

Then build kernel with following script
```
./hack kernel-build IDEN
```
Note that, MacOS/Windows should execute this script in docker shell. Linux should either install the essential tools or use the docker for building kernel image.

This will build a kernel image. The building process can be modified for different purposes.


### Run Kernel with QEMU
First you should install [QEMU](https://www.qemu.org).
Then run kernel with 
```
./hack kernel-run
```
The kernel will boot, and spawn a login shell. Then you can start hacking. 

**Note that** the script uses `hvf` for acceleration, which should be modified according to your case. You can run `qemu-system-x86_64 -accel help` to see acceleration that can be used. For example if `kvm` is in the output, you can adopt kvm acceleration with env variable ACCEL like `ACCEL=kvm ./hack kernel-run`. You can always use `ACCEL=tcg` for software virtualization.


### (Optional) Install Modules
You can install modules to the running qemu instance to safely use kernel module functionalities by running
```
./hack kernel-module-install
```


### (Optional) Using SSH Utilities
You can ssh to the running qemu instance with
```
./hack kernel-ssh
```
or sftp to int with
```
./hack kernel-sftp
``` 
you can also use a helper script to send file or directories to the running qemu instance
```
./hack kernel-sync SRC [DST] # DST is optional, the file will be extracted to /root by default
```
