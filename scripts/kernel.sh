#!/bin/bash
set -Eeuo pipefail
umask 022
target=$1
jobs=${BRAVION_JOBS:-1}
base=/build/lfs
mkdir -p /build/kernel "$base/boot/firmware"
if [[ "$target" == amd64 ]]; then
 source=/build/kernel/linux-6.18.10
 [[ -d "$source" ]] || tar -xf /build/lfs/sources/linux-6.18.10.tar.xz -C /build/kernel
 cd "$source"
 if ! grep -q 'VirtIO scanouts are desktop monitors' drivers/gpu/drm/virtio/virtgpu_display.c; then patch -Np1 -i /workspace/patches/kernel/virtio-desktop.patch; fi
 make ARCH=x86_64 defconfig
 scripts/config --set-str LOCALVERSION -bravion --enable MODULES --enable EFI --enable EFI_STUB --enable EFI_PARTITION
 scripts/config --enable CMDLINE_BOOL --enable CMDLINE_OVERRIDE --set-str CMDLINE 'root=PARTUUID=4c465350-02 rootfstype=ext4 rootwait rw console=tty0 console=ttyS0,115200 net.ifnames=0'
 for option in EXT4_FS DEVTMPFS DEVTMPFS_MOUNT BLK_DEV_NVME SATA_AHCI SCSI BLK_DEV_SD ATA VIRTIO VIRTIO_PCI VIRTIO_BLK VIRTIO_NET VIRTIO_CONSOLE DRM DRM_VIRTIO_GPU DRM_SIMPLEDRM FRAMEBUFFER_CONSOLE FB_EFI VT VT_CONSOLE USB_XHCI_HCD USB_XHCI_PCI USB_EHCI_HCD USB_OHCI_HCD USB_STORAGE USB_UAS HID HID_GENERIC USB_HID INPUT_EVDEV SERIAL_8250 SERIAL_8250_CONSOLE UNIX INET IPV6 PACKET TMPFS CFG80211 RFKILL FW_LOADER USER_NS SECCOMP SECCOMP_FILTER CGROUPS NAMESPACES; do scripts/config --enable "$option"; done
 for option in DRM_AMDGPU DRM_I915 DRM_XE E1000 E1000E IGB IGC R8169 IWLWIFI ATH9K ATH10K_PCI ATH11K_PCI BRCMFMAC RTW88 RTW89 VSOCKETS VIRTIO_VSOCKETS SOUND SND SND_HDA_INTEL SND_USB_AUDIO SND_VIRTIO FUSE_FS; do scripts/config --module "$option"; done
 make ARCH=x86_64 olddefconfig
 make ARCH=x86_64 -j"$jobs" bzImage modules
 make ARCH=x86_64 INSTALL_MOD_PATH="$base" INSTALL_MOD_STRIP=1 modules_install
 mkdir -p "$base/boot/firmware/EFI/BOOT"
 install -m644 arch/x86/boot/bzImage "$base/boot/firmware/EFI/BOOT/BOOTX64.EFI"
 cp .config "$base/boot/firmware/kernel.config"
 make -s kernelrelease > "$base/boot/firmware/kernel.release"
else
 source=/build/kernel/linux-ab4372076bb840600e522ae776887ae2bc488fa6
 [[ -d "$source" ]] || tar -xf /build/pi/linux-ab437207.tar.gz -C /build/kernel
 cd "$source"
 cp /workspace/kernel/arm64.config .config
 if ! grep -q 'VirtIO scanouts are desktop monitors' drivers/gpu/drm/virtio/virtgpu_display.c; then patch -Np1 -i /workspace/patches/kernel/virtio-desktop.patch; fi
 make ARCH=arm64 olddefconfig
 make ARCH=arm64 -j"$jobs" Image modules dtbs
 make ARCH=arm64 INSTALL_MOD_PATH="$base" INSTALL_MOD_STRIP=1 modules_install
 cp .config "$base/boot/firmware/kernel.config"
 make -s kernelrelease > "$base/boot/firmware/kernel.release"
 if [[ "$target" == parallels-arm64 ]]; then
  mkdir -p "$base/boot/firmware/EFI/BOOT"
  install -m644 arch/arm64/boot/Image "$base/boot/firmware/EFI/BOOT/BOOTAA64.EFI"
  rm -f "$base/boot/firmware/kernel8.img"
 else
  install -m644 arch/arm64/boot/Image "$base/boot/firmware/kernel8.img"
  install -m644 arch/arm64/boot/dts/broadcom/bcm2711-rpi-4-b.dtb "$base/boot/firmware/"
  mkdir -p "$base/boot/firmware/overlays"
  cp arch/arm64/boot/dts/overlays/*.dtbo "$base/boot/firmware/overlays/"
 fi
 bash /workspace/build/firmware.sh
 if [[ "$target" == parallels-arm64 ]]; then rm -f "$base/boot/firmware/start4.elf" "$base/boot/firmware/fixup4.dat"; fi
fi
cp COPYING "$base/boot/firmware/LICENSE.kernel"
chroot "$base" /sbin/depmod -a "$(cat "$base/boot/firmware/kernel.release")"
