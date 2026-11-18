#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/fuse-3.18.1
sed -i '/^udev/,$ s/^/#/' util/meson.build
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Dexamples=false -Dtests=false 
ninja -j2 -C build
ninja -C build install
chmod u+s /usr/bin/fusermount3
ldconfig
