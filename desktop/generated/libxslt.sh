#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libxslt-1.1.45
./configure --prefix=/usr --disable-static --without-python
make -j2
make install
ldconfig
