#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libXt-1.3.1
./configure --prefix=/usr --disable-static --disable-devel-docs --with-appdefaultdir=/etc/X11/app-defaults
make -j2
make install
ldconfig
