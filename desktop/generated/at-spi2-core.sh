#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/at-spi2-core-2.58.3
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Dgtk2_atk_adaptor=false -Dintrospection=enabled -Ddocs=false -Dx11=enabled
ninja -j2 -C build
ninja -C build install
flock /run/desktop-ldconfig.lock ldconfig
