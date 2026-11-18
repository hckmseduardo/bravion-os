#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/librsvg-2.61.4
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Dintrospection=enabled -Dpixbuf=enabled -Dpixbuf-loader=enabled -Ddocs=disabled -Dvala=disabled -Dtests=false -Davif=enabled
ninja -j2 -C build
ninja -C build install
gdk-pixbuf-query-loaders --update-cache
flock /run/desktop-ldconfig.lock ldconfig
