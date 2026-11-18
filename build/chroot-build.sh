#!/bin/bash
set -euo pipefail
umask 022
export LFS=/build/lfs
if test ! -e /build/chroot-ownership-done; then
    chown -h root:root "$LFS" "$LFS"/{bin,lib,sbin}
    chown -R root:root "$LFS"/{usr,etc,var,tools}
    touch /build/chroot-ownership-done
fi
mkdir -p "$LFS"/{dev,proc,sys,run,build-scripts,build-logs,build-done}
mountpoint -q "$LFS/dev" || mount --bind /dev "$LFS/dev"
mountpoint -q "$LFS/dev/pts" || mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
mountpoint -q "$LFS/proc" || mount -t proc proc "$LFS/proc"
mountpoint -q "$LFS/sys" || mount -t sysfs sysfs "$LFS/sys"
mountpoint -q "$LFS/run" || mount -t tmpfs tmpfs "$LFS/run"
if test -L "$LFS/dev/shm"; then mkdir -p "$LFS/$(readlink "$LFS/dev/shm")"; else mountpoint -q "$LFS/dev/shm" || mount -t tmpfs -o nosuid,nodev tmpfs "$LFS/dev/shm"; fi
cp -a /workspace/build/scripts/. "$LFS/build-scripts/"
cp /etc/resolv.conf "$LFS/etc/resolv.conf"
python3 /workspace/build/run-chroot.py
