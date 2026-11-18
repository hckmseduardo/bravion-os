#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/polkit-127
getent group polkitd >/dev/null || groupadd -g 27 polkitd
id polkitd >/dev/null 2>&1 || useradd -c "PolicyKit Daemon Owner" -d /etc/polkit-1 -u 27 -g polkitd -s /bin/false polkitd
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Dman=false -Dsession_tracking=logind -Dtests=false
ninja -j2 -C build
ninja -C build install
ldconfig
