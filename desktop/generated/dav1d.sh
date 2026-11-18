#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/dav1d-1.5.3
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Denable_tests=false -Denable_tools=false
ninja -j2 -C build
ninja -C build install
flock /run/desktop-ldconfig.lock ldconfig
