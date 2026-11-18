#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libglvnd-1.7.0
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Dx11=enabled -Dglx=enabled -Degl=true -Dgles1=true -Dgles2=true -Dheaders=true
ninja -j2 -C build
ninja -C build install
ldconfig
