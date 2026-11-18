#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/flatpak-1.18.4
meson setup build --prefix=/usr --libdir=lib --buildtype=release --sysconfdir=/etc --localstatedir=/var -Dsystemd=enabled -Dsystem_helper=enabled -Dseccomp=enabled -Dsystem_bubblewrap=/usr/bin/bwrap -Dsystem_dbus_proxy=/usr/bin/xdg-dbus-proxy -Dmalcontent=disabled -Dgtkdoc=disabled -Ddocbook_docs=disabled -Dman=disabled -Dtests=false
ninja -j2 -C build
ninja -C build install
flock /run/desktop-ldconfig.lock ldconfig
