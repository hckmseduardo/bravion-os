#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/bubblewrap-0.11.0
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Dman=disabled -Dtests=false
ninja -j2 -C build
ninja -C build install
ldconfig
