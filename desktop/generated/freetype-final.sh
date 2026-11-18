#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/freetype-2.14.1
./configure --prefix=/usr --disable-static --with-harfbuzz=yes
make -j2
make install
ldconfig
