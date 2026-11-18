#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/fribidi-1.0.16
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Ddocs=false -Dtests=false
ninja -j2 -C build
ninja -C build install
ldconfig
