#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/wireplumber-0.5.13
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Dsystem-lua=true -Dsystemd=enabled -Dsystemd-user-service=true -Dsystemd-system-service=false -Ddoc=disabled -Dtests=false -Ddbus-tests=false
ninja -j2 -C build
ninja -C build install
ldconfig
