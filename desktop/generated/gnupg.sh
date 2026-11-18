#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/gnupg-2.5.17
mkdir -p build
cd build
../configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc --disable-doc
make -j2
make install
ldconfig
