#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/xdg-desktop-portal-gtk-1.15.3
meson setup build --prefix=/usr --libdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release --wrap-mode=nofallback -Dwallpaper=disabled -Dsettings=disabled
ninja -j2 -C build
ninja -C build install
flock /run/desktop-ldconfig.lock ldconfig
