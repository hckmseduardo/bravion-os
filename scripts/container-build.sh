#!/bin/bash
set -Eeuo pipefail
umask 022
[[ $EUID == 0 && $# == 1 && -d /storage && -d /workspace ]]
case "$1" in pi4-arm64|parallels-arm64|amd64) ;; *) exit 2;; esac
# A regular, newly-created sparse file stores the Linux filesystem on any host.
# No physical drive is selected, partitioned, or formatted by this script.
exec 9>/storage/build.lock
flock -n 9 || { echo 'This storage directory is already building'; exit 1; }
file=/storage/build.ext4
if [[ ! -e "$file" ]]; then
 (set -C; : > "$file")
 truncate -s 128G "$file"
 mkfs.ext4 -q -F -L BRAVIONBUILD "$file"
fi
[[ -f "$file" && ! -L "$file" ]]
mkdir -p /build /outputs /status
mount --bind /storage/outputs /outputs
mount --bind /storage/status /status
mount -o loop "$file" /build
cleanup(){ sync; umount -R /build || true; umount /outputs || true; umount /status || true; }
trap cleanup EXIT
export BRAVION_STATUS=/status/status.json
python3 /workspace/build/pipeline.py "$1"
