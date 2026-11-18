#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libsndfile-1.2.2
export CFLAGS="-O2 -std=gnu17"
./configure --prefix=/usr --disable-static --disable-external-libs --disable-mpeg
make -j2
make install
ldconfig
