#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/alsa-lib-1.2.15.3
./configure --prefix=/usr --disable-static 
make -j2
make install
ldconfig
