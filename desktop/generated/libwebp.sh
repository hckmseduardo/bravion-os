#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libwebp-1.6.0
./configure --prefix=/usr --disable-static --enable-libwebpmux --enable-libwebpdemux --enable-libwebpdecoder --enable-swap-16bit-csp
make -j2
make install
flock /run/desktop-ldconfig.lock ldconfig
