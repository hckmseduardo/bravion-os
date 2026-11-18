#!/bin/bash
set -euo pipefail
umask 022
r=/build/desktop-lfs
if ! test -e /build/desktop-root-prepared; then
 mkdir -p "$r"
 rsync -aHAXx --numeric-ids --exclude=/sources --exclude=/tools --exclude=/build-scripts --exclude=/build-logs --exclude=/build-done --exclude=/dev --exclude=/proc --exclude=/sys --exclude=/run --exclude=/tmp /build/lfs/ "$r/"
 mkdir -p "$r"/{dev,proc,sys,run,tmp,sources,desktop-scripts,desktop-logs,desktop-done}
 chmod 1777 "$r/tmp"
 touch /build/desktop-root-prepared
fi
mountpoint -q "$r/dev" || mount --rbind /dev "$r/dev"
mount --make-rslave "$r/dev"
mountpoint -q "$r/proc" || mount -t proc proc "$r/proc"
mountpoint -q "$r/sys" || mount -t sysfs sysfs "$r/sys"
# Private runtime mount; build helpers must not affect host services.
mountpoint -q "$r/run" || mount -t tmpfs tmpfs "$r/run"
rm -f "$r/etc/resolv.conf"
cp /etc/resolv.conf "$r/etc/resolv.conf"
chroot "$r" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin TERM=xterm /bin/bash -c 'umask 022; gcc -dumpmachine; printf "int main(){return 0;}\n" >/tmp/verify.c; gcc /tmp/verify.c -o /tmp/verify; /tmp/verify; stat -c "%u %g %a %n" / /usr/bin/sudo'
