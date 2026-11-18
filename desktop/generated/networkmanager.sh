#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/NetworkManager-1.56.0
meson setup build --prefix=/usr --libdir=lib --buildtype=release --sysconfdir=/etc --localstatedir=/var -Dlibaudit=no -Dnmtui=false -Dovs=false -Dppp=false -Dnbft=false -Dselinux=false -Dqt=false -Dsession_tracking=systemd -Dnm_cloud_setup=false -Dmodem_manager=false -Dcrypto=gnutls -Dintrospection=true -Dvapi=false -Dtests=no -Dman=false -Ddocs=false -Dlibpsl=true -Dpolkit=true
ninja -j2 -C build
ninja -C build install
ldconfig
