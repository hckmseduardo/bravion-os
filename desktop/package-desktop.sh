#!/bin/bash
# Package a prepared, clean ARM64 LFS desktop root into a regular image file.
set -euo pipefail
umask 022
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
root=${BRAVION_ROOT:-/build/desktop-lfs}
version=${BRAVION_VERSION:-$(cat /workspace/VERSION)}
target=${BRAVION_TARGET:-pi4-arm64}
case "$target" in
 pi4-arm64) suffix=raspberry-pi4-arm64; boot_type=c ;;
 parallels-arm64) suffix=parallels-arm64; boot_type=ef ;;
 amd64) suffix=amd64; boot_type=ef ;;
 *) echo "Invalid image target" >&2; exit 2 ;;
esac
[[ $version =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || exit 2
name=bravion-os-$version-$suffix.img
image=
export_image=/outputs/$name
MiB=1048576
boot_mib=96
root=$(realpath -e "$root")
[[ "$root" != / && -f "$root/etc/lfs-release" && ! -e "$root/var/lib/pi-lfs/setup-complete" ]]
[[ -z $(find "$root/home" -mindepth 1 -maxdepth 1 -print -quit) ]]
[[ $EUID == 0 && -d "$root/usr" && -d "$root/boot/firmware" ]]
mkdir -p /build /outputs /build/package-receipts
receipt=/build/package-receipts/$name.receipt
receipt_sha=''
if [[ -e "$receipt" || -L "$receipt" ]]; then
 [[ -f "$receipt" && ! -L "$receipt" ]] || exit 1
 read -r tag recorded_target recorded_version receipt_sha extra < "$receipt"
 [[ "$tag" == BRAVION_PACKAGE_V1 && "$recorded_target" == "$target" && "$recorded_version" == "$version" && "$receipt_sha" =~ ^[0-9a-f]{64}$ && -z "$extra" ]] || exit 1
fi
if [[ -e "$export_image" || -L "$export_image" ]]; then
 [[ -f "$export_image" && ! -L "$export_image" && -n "$receipt_sha" ]] || { echo "Refusing unknown existing output: $export_image" >&2; exit 1; }
 [[ $(sha256sum "$export_image" | awk '{print $1}') == "$receipt_sha" ]] || { echo 'Existing package does not match its verified receipt' >&2; exit 1; }
 if [[ -e "$export_image.sha256" || -L "$export_image.sha256" ]]; then
  [[ -f "$export_image.sha256" && ! -L "$export_image.sha256" && $(cat "$export_image.sha256") == "$receipt_sha  $name" ]] || exit 1
 else
  (set -C; printf '%s  %s\n' "$receipt_sha" "$name" > "$export_image.sha256")
 fi
 echo "Reused verified package $export_image"
 exit 0
fi
if [[ -e "$export_image.sha256" || -L "$export_image.sha256" ]]; then
 [[ -n "$receipt_sha" && -f "$export_image.sha256" && ! -L "$export_image.sha256" && $(cat "$export_image.sha256") == "$receipt_sha  $name" ]] || exit 1
 rm -- "$export_image.sha256"
fi
[[ -z "$receipt_sha" ]] || rm -- "$receipt"
# Preserve native Rust, GCC/binutils, shared libraries and development headers.
# Only staging content, caches, virtual filesystems, and separately copied boot files are excluded.
excludes=(/sources /tools /build-scripts /build-logs /build-done
          /desktop-scripts /desktop-logs /desktop-done
          /dev /proc /sys /run /tmp /boot/firmware
          /opt/buildtools /root/.cache /root/.cargo /usr/share/man /usr/share/info /usr/share/gtk-doc
          /root/.rustup/downloads /root/.rustup/tmp
          /var/cache /var/tmp)
du_args=()
rsync_args=()
find_args=()
for p in "${excludes[@]}"; do
    du_args+=("--exclude=$root$p")
    rsync_args+=("--exclude=$p/***")
    find_args+=(-path "$root$p" -o)
done
# Remove the final '-o', then prune the identical directory set for inode counting.
unset 'find_args[${#find_args[@]}-1]'
installed_bytes=$(du -sx -B1 "${du_args[@]}" "$root" | awk '{print $1}')
inode_entries=$(find "$root" -xdev \( "${find_args[@]}" \) -prune -o -printf '.\n' | wc -l)
# Plenty of inodes for source development after boot; block reserve covers metadata and updates.
inodes=$(( inode_entries + inode_entries / 2 + 32768 ))
reserve_bytes=$(( installed_bytes / 6 + 512 * MiB ))
root_mib=$(( (installed_bytes + reserve_bytes + MiB - 1) / MiB ))
# Root starts on a MiB boundary after a one-MiB partition-table gap and FAT boot partition.
image_mib=$(( 1 + boot_mib + root_mib ))
boot_bytes=$(du -sLB1 "$root/boot/firmware" | awk '{print $1}')
(( boot_bytes + 16 * MiB < boot_mib * MiB )) || { echo 'Boot files do not fit the 96 MiB FAT partition with reserve' >&2; exit 1; }
# Fail before image creation if the boot configuration or fstab identifies a different disk.
grep -Eq '^PARTUUID=4c465350-02[[:space:]]+/[[:space:]]+ext4' "$root/etc/fstab"
grep -Eq '^PARTUUID=4c465350-01[[:space:]]+/boot/firmware[[:space:]]+vfat' "$root/etc/fstab"
if [[ "$target" == pi4-arm64 ]]; then
 grep -q 'root=PARTUUID=4c465350-02' "$root/boot/firmware/cmdline.txt"
else
 [[ -s "$root/boot/firmware/EFI/BOOT/BOOTX64.EFI" || -s "$root/boot/firmware/EFI/BOOT/BOOTAA64.EFI" ]]
fi
mkdir -p /build /outputs
logdir=$(mktemp -d /build/desktop-package-checks.XXXXXX)
printf 'Installed bytes: %s\nEntries: %s\nRequested inodes: %s\nBoot bytes: %s\nBoot MiB: %s\nRoot MiB: %s\nImage MiB: %s\n' \
    "$installed_bytes" "$inode_entries" "$inodes" "$boot_bytes" "$boot_mib" "$root_mib" "$image_mib" | tee "$logdir/sizing.txt"
# The export mount reports host disk space; the build volume itself is thin-provisioned.
export_free=$(df -B1 --output=avail /outputs | tail -1)
(( export_free >= image_mib * MiB * 2 )) || { echo 'Insufficient host space for image export and validation' >&2; exit 1; }
# Each attempt owns a unique staging directory. Failed attempts never occupy
# the final filename, so a retry does not require deleting a partial image.
workdir=$(mktemp -d /build/.bravion-package.XXXXXX)
image=$workdir/$name
loop=''
mountdir=''
export_tmp=''
receipt_tmp=''
cleanup() {
    set +e
    if [[ -n "$mountdir" ]]; then
        mountpoint -q "$mountdir/boot/firmware" && umount "$mountdir/boot/firmware"
        mountpoint -q "$mountdir" && umount "$mountdir"
    fi
    [[ -z "$loop" ]] || losetup -d "$loop"
    [[ -z "$export_tmp" ]] || rm -f -- "$export_tmp"
    [[ -z "$receipt_tmp" ]] || rm -f -- "$receipt_tmp"
    if [[ -z "$mountdir" ]] || ! mountpoint -q "$mountdir"; then rm -rf -- "$workdir"; fi
    return 0
}
trap cleanup EXIT
(set -o noclobber; : > "$image")
[[ -f "$image" && ! -L "$image" ]]
truncate -s "$(( image_mib * MiB ))" "$image"
sfdisk "$image" <<EOF
label: dos
label-id: 0x4c465350
unit: sectors

start=2048, size=$(( boot_mib * 2048 )), type=$boot_type, bootable
start=$(( (boot_mib + 1) * 2048 )), size=$(( root_mib * 2048 )), type=83
EOF
mountdir=$(mktemp -d "$workdir/root.XXXXXX")
loop=$(losetup --find --show --partscan "$image")
# Docker has no udev: create only the nodes belonging to this newly allocated loop.
for number in 1 2; do
    node="${loop}p${number}"
    for attempt in $(seq 1 20); do
        [[ -e /sys/class/block/$(basename "$node")/dev ]] && break
        sleep 1
    done
    device=$(cat "/sys/class/block/$(basename "$node")/dev")
    expected=$(printf '%x:%x' "${device%:*}" "${device#*:}")
    if [[ -e "$node" || -L "$node" ]]; then
        if [[ -L "$node" || ! -b "$node" || $(stat -c '%t:%T' "$node") != "$expected" ]]; then
            # Replace only a stale /dev node, never follow it or write its device data.
            python3 -c 'from pathlib import Path; import sys; Path(sys.argv[1]).unlink()' "$node"
        fi
    fi
    [[ -b "$node" ]] || mknod "$node" b "${device%:*}" "${device#*:}"
    [[ $(stat -c '%t:%T' "$node") == "$expected" ]]
done
mkfs.vfat -F32 -n PILFSBOOT "${loop}p1"
mkfs.ext4 -F -m 0 -N "$inodes" -L PILFSROOT -O '^metadata_csum_seed' "${loop}p2"
mount "${loop}p2" "$mountdir"
rsync -aHAXx --numeric-ids "${rsync_args[@]}" "$root/" "$mountdir/"
mkdir -p "$mountdir"/{dev,proc,sys,run,tmp,boot/firmware,var/cache,var/tmp}
chmod 1777 "$mountdir/tmp" "$mountdir/var/tmp"
mount "${loop}p1" "$mountdir/boot/firmware"
cp -rL --sparse=never "$root/boot/firmware/." "$mountdir/boot/firmware/"
# Sources are excluded, so kernel development symlinks into the source tree are dangling.
if [[ -d "$mountdir/usr/lib/modules" ]]; then
    find "$mountdir/usr/lib/modules" -maxdepth 2 -type l \( -name build -o -name source \) -delete
fi
df -B1 "$mountdir" | tee "$logdir/root-space.txt"
free_bytes=$(df -B1 --output=avail "$mountdir" | tail -1)
(( free_bytes >= 512 * MiB )) || { echo 'Packaged root has less than 512 MiB free' >&2; exit 1; }
sync
umount "$mountdir/boot/firmware"
umount "$mountdir"
fsck.vfat -n "${loop}p1" > "$logdir/boot-filesystem-check.txt" 2>&1
e2fsck -fn "${loop}p2" > "$logdir/root-filesystem-check.txt" 2>&1
sfdisk --dump "$image" > "$logdir/partition-table.txt"
blkid "${loop}p1" "${loop}p2" > "$logdir/partition-identifiers.txt"
[[ $(blkid -s PARTUUID -o value "${loop}p1") == 4c465350-01 ]]
[[ $(blkid -s PARTUUID -o value "${loop}p2") == 4c465350-02 ]]
losetup -d "$loop"
loop=''
# virtiofs can reject sparse-copy probes; use an explicit non-sparse copy to a new staging file.
export_tmp=$(mktemp /outputs/.$name.XXXXXX)
cp --sparse=never "$image" "$export_tmp"
image_sha=$(sha256sum "$image" | awk '{print $1}')
[[ $(sha256sum "$export_tmp" | awk '{print $1}') == "$image_sha" ]]
# Persist proof of verified ownership before publishing. A crash between the
# image and sidecar publication is recoverable without trusting unknown files.
receipt_tmp=$(mktemp /build/package-receipts/.receipt.XXXXXX)
printf 'BRAVION_PACKAGE_V1 %s %s %s\n' "$target" "$version" "$image_sha" > "$receipt_tmp"
ln "$receipt_tmp" "$receipt"
rm -- "$receipt_tmp"
receipt_tmp=''
# A hard link is atomic and fails if the final path appeared in the meantime.
ln "$export_tmp" "$export_image"
rm -f -- "$export_tmp"
export_tmp=''
(set -o noclobber; printf '%s  %s\n' "$image_sha" "$(basename "$export_image")" > "$export_image.sha256")
echo "Created $export_image; checks: $logdir"
