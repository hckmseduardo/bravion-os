#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libunistring-1.4.1
sed -r '/_GL_EXTERN_C/s/w?memchr|bsearch/(&)/' -i $(find -name \*.in.h)
./configure --prefix=/usr --disable-static 
make -j2
make install
ldconfig
