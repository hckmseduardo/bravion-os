#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/cairo-1.18.4
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Dfontconfig=enabled -Dfreetype=enabled -Dpng=enabled -Dxcb=enabled -Dxlib=enabled -Dglib=enabled -Dtests=disabled -Dgtk_doc=false
ninja -j2 -C build
ninja -C build install
ldconfig
