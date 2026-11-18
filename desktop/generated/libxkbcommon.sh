#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libxkbcommon-1.13.1
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Denable-docs=false -Denable-x11=false -Denable-wayland=true
ninja -j2 -C build
ninja -C build install
ldconfig
