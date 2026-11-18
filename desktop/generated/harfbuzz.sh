#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/harfbuzz-12.3.2
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Dfreetype=enabled -Dglib=enabled -Dgobject=enabled -Dcairo=disabled -Dicu=disabled -Dgraphite2=disabled -Dintrospection=enabled -Dtests=disabled -Ddocs=disabled -Dutilities=disabled
ninja -j2 -C build
ninja -C build install
ldconfig
