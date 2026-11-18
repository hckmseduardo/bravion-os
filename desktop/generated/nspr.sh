#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/nspr-4.38.2
cd nspr
sed -i '/^RELEASE/s|^|#|' pr/src/misc/Makefile.in
sed -i 's|$(LIBRARY) ||' config/rules.mk
./configure --prefix=/usr --with-mozilla --with-pthreads --enable-64bit
make -j2
make install
flock /run/desktop-ldconfig.lock ldconfig
