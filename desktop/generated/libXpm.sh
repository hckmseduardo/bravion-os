#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libXpm-3.5.18
./configure --prefix=/usr --disable-static --disable-devel-docs --disable-open-zfile
make -j2
make install
ldconfig
