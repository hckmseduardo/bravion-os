#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/upower-v1.91.1
pkg-config --exists gudev-1.0 polkit-gobject-1
meson setup build --prefix=/usr --libdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release --wrap-mode=nofallback -Dgtk-doc=false -Dman=false -Didevice=disabled -Dpolkit=enabled -Dinstalled_tests=false -Dintrospection=enabled -Dzshcompletiondir=no -Dhistorydir=/var/lib/upower -Dstatedir=/var/lib/upower
ninja -j2 -C build
ninja -j2 -C build install
ldconfig
