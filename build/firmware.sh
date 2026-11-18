#!/bin/bash
set -euo pipefail
umask 022
set -x
boot=/build/lfs/boot/firmware
mkdir -p "$boot" /build/lfs/usr/lib/firmware/brcm /build/lfs/usr/share/licenses/pi-lfs
revision=896fc67d292bfde6d9889d4c585bb685758dc1ad
for file in start4.elf fixup4.dat LICENCE.broadcom; do
    curl -4 -fL --retry 3 "https://raw.githubusercontent.com/raspberrypi/firmware/$revision/boot/$file" -o "$boot/$file"
done
cd /build/pi
sha256sum -c wifi-source.sha256
source=firmware-nonfree-5d2295b633d94641253e16ba90fc847436fc9d4a/debian
install -m644 "$source/added-firmware/cypress/cyfmac43455-sdio-standard.bin" /build/lfs/usr/lib/firmware/brcm/brcmfmac43455-sdio.bin
install -m644 "$source/added-firmware/cypress/cyfmac43455-sdio.clm_blob" /build/lfs/usr/lib/firmware/brcm/brcmfmac43455-sdio.clm_blob
install -m644 "$source/added-firmware/brcm/brcmfmac43455-sdio.txt" /build/lfs/usr/lib/firmware/brcm/brcmfmac43455-sdio.txt
for extension in bin clm_blob txt; do
    ln -sf "brcmfmac43455-sdio.$extension" "/build/lfs/usr/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,4-model-b.$extension"
done
cp "$source/copyright" /build/lfs/usr/share/licenses/pi-lfs/WIFI-firmware-copyright
curl -4 -fL --retry 3 https://www.kernel.org/pub/software/network/wireless-regdb/wireless-regdb-2025.10.07.tar.xz -o wireless-regdb-2025.10.07.tar.xz
tar -xf wireless-regdb-2025.10.07.tar.xz
install -m644 wireless-regdb-2025.10.07/regulatory.db wireless-regdb-2025.10.07/regulatory.db.p7s /build/lfs/usr/lib/firmware/
cp wireless-regdb-2025.10.07/LICENSE /build/lfs/usr/share/licenses/pi-lfs/WIRELESS-regdb-license
sha256sum "$boot"/{start4.elf,fixup4.dat} wireless-regdb-2025.10.07.tar.xz > /workspace/logs/firmware-sha256.txt
