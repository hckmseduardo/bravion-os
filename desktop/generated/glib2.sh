#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/glib-2.86.4
curl -fL https://www.linuxfromscratch.org/patches/blfs/13.0/glib-2.86.4-upstream_fixes-1.patch -o /sources/glib-2.86.4-upstream_fixes-1.patch
patch -Np1 -i /sources/glib-2.86.4-upstream_fixes-1.patch
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Dintrospection=disabled -Dglib_debug=disabled -Dman-pages=disabled -Dsysprof=disabled -Dtests=false
ninja -j2 -C build
ninja -C build install
ldconfig
