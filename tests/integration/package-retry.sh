#!/bin/bash
set -euo pipefail
# Run only in a disposable privileged Docker builder with empty /build and
# /outputs. This deliberately replaces mkfs.vfat temporarily to inject failure.
[[ -f /.dockerenv && $EUID == 0 && $# == 1 && -d /build && -d /outputs && ! -e /fixture ]]
script=$1
[[ -f "$script" ]]
r=/fixture
mkdir -p "$r"/{etc,home,usr,boot/firmware}
printf test > "$r/etc/lfs-release"
printf 'PARTUUID=4c465350-02 / ext4 defaults 0 1\nPARTUUID=4c465350-01 /boot/firmware vfat defaults 0 2\n' > "$r/etc/fstab"
printf 'root=PARTUUID=4c465350-02\n' > "$r/boot/firmware/cmdline.txt"
dd if=/dev/zero of="$r/usr/test-data" bs=1M count=256 status=none
export BRAVION_ROOT=$r BRAVION_TARGET=pi4-arm64 BRAVION_VERSION=retry-test
mv /usr/sbin/mkfs.vfat /usr/sbin/mkfs.vfat.real
printf '#!/bin/sh\nexit 73\n' >/usr/sbin/mkfs.vfat
chmod 755 /usr/sbin/mkfs.vfat
set +e
bash "$script" > /outputs/first-attempt.log 2>&1
result=$?
set -e
[[ $result == 73 ]]
mv /usr/sbin/mkfs.vfat.real /usr/sbin/mkfs.vfat
bash "$script" > /outputs/retry.log 2>&1
rm /outputs/bravion-os-retry-test-raspberry-pi4-arm64.img.sha256
bash "$script" > /outputs/checksum-recovery.log 2>&1
(cd /outputs; sha256sum -c bravion-os-retry-test-raspberry-pi4-arm64.img.sha256)
echo 'PASS: interrupted package retries and missing checksum recovers without manual image removal'
