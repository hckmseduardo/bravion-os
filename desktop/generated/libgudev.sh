#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libgudev-238
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Dintrospection=enabled -Dtests=disabled -Dvapi=disabled
ninja -j2 -C build
ninja -C build install
ldconfig
