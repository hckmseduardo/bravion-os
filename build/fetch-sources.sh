#!/bin/bash
set -euo pipefail
umask 022
mkdir -p /build/lfs/sources
cd /build/lfs/sources
cp /workspace/research/{wget-list,md5sums} .
sed 's@https://ftpmirror.gnu.org/@https://mirrors.kernel.org/gnu/@' wget-list | xargs -P4 -n1 wget -4 -nv -c --timeout=40 --tries=3
md5sum -c md5sums
urls=(
https://github.com/thom311/libnl/releases/download/libnl3_12_0/libnl-3.12.0.tar.gz
https://www.kernel.org/pub/software/network/iw/iw-6.17.tar.xz
https://w1.fi/releases/wpa_supplicant-2.11.tar.gz
https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-10.2p1.tar.gz
https://www.sudo.ws/dist/sudo-1.9.17p2.tar.gz
https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-10.6p2.tar.gz
https://github.com/openssl/openssl/releases/download/openssl-3.5.9/openssl-3.5.9.tar.gz
https://github.com/openssl/openssl/releases/download/openssl-3.5.9/openssl-3.5.9.tar.gz.sha256
https://curl.se/download/curl-8.23.0.tar.xz
https://github.com/dosfstools/dosfstools/releases/download/v4.2/dosfstools-4.2.tar.gz
)
for url in "${urls[@]}"; do wget -4 -nv -c --timeout=40 --tries=3 "$url"; done
cat > blfs-md5sums <<'EOF'
f9112ca215807fe65eecd583d8f180cc  libnl-3.12.0.tar.gz
7323e43843f30068ffb6079e15e8e11a  iw-6.17.tar.xz
72a4a00eddb7a499a58113c3361ab094  wpa_supplicant-2.11.tar.gz
801b5ad6da38e0045de20dd5dd2f6a80  openssh-10.2p1.tar.gz
EOF
md5sum -c blfs-md5sums
sha256sum -c openssl-3.5.9.tar.gz.sha256
printf '%s  %s\n' 9ae44872090cf2f06b3cf9ff147e7f16f309671340763ed2f99248398ae29d5b openssh-10.6p2.tar.gz | sha256sum -c -
mkdir -p /build/pi
cd /build/pi
curl -4 -fL --retry 3 https://codeload.github.com/raspberrypi/linux/tar.gz/ab4372076bb840600e522ae776887ae2bc488fa6 -o linux-ab437207.tar.gz
curl -4 -fL --retry 3 https://codeload.github.com/RPi-Distro/firmware-nonfree/tar.gz/5d2295b633d94641253e16ba90fc847436fc9d4a -o wifi-firmware.tar.gz
sha256sum linux-ab437207.tar.gz > linux-source.sha256
sha256sum wifi-firmware.tar.gz > wifi-source.sha256
tar -xf wifi-firmware.tar.gz
