#!/bin/bash
set -euo pipefail
umask 022
set -x
cd /build/pi
sha256sum -c linux-source.sha256
test -d linux-ab4372076bb840600e522ae776887ae2bc488fa6 || tar -xf linux-ab437207.tar.gz
cd linux-ab4372076bb840600e522ae776887ae2bc488fa6
make ARCH=arm64 bcm2711_defconfig
# Make boot storage and root filesystem available without an initramfs.
for option in USB_XHCI_HCD USB_XHCI_PCI USB_XHCI_PLATFORM USB_DWC2 USB_STORAGE USB_UAS EXT4_FS MMC MMC_BCM2835 MMC_SDHCI MMC_SDHCI_PLTFM MMC_SDHCI_IPROC DEVTMPFS DEVTMPFS_MOUNT TMPFS UNIX INET IPV6 PACKET CFG80211 RFKILL FW_LOADER BCMGENET MDIO_BCM_UNIMAC BROADCOM_PHY; do scripts/config --enable "$option"; done
scripts/config --module BRCMFMAC --enable BRCMFMAC_SDIO --enable CFG80211_REQUIRE_SIGNED_REGDB
scripts/config --enable DRM --enable DRM_VC4 --enable DRM_FBDEV_EMULATION --enable FRAMEBUFFER_CONSOLE --enable VT --enable VT_CONSOLE
# Also permit a QEMU virt smoke boot with the same kernel and root filesystem.
for option in ARCH_VIRT VIRTIO VIRTIO_MMIO VIRTIO_PCI VIRTIO_BLK VIRTIO_NET SERIAL_AMBA_PL011 SERIAL_AMBA_PL011_CONSOLE; do scripts/config --enable "$option"; done
make ARCH=arm64 olddefconfig
make ARCH=arm64 -j1 Image modules dtbs
make ARCH=arm64 INSTALL_MOD_PATH=/build/lfs INSTALL_MOD_STRIP=1 modules_install
install -d /build/lfs/boot/firmware/overlays
install -m644 arch/arm64/boot/Image /build/lfs/boot/firmware/kernel8.img
install -m644 arch/arm64/boot/dts/broadcom/bcm2711-rpi-4-b.dtb /build/lfs/boot/firmware/
install -m644 arch/arm64/boot/dts/overlays/*.dtbo /build/lfs/boot/firmware/overlays/
cp .config /build/lfs/boot/firmware/kernel.config
make -s kernelrelease > /build/lfs/boot/firmware/kernel.release
cp COPYING /build/lfs/boot/firmware/LICENSE.kernel
