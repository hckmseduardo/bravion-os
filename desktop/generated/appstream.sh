#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/AppStream-1.1.2
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Dapidocs=false -Ddocs=false -Dman=false -Dbash-completion=false -Dstemming=false -Dcompose=false -Dqt=false
ninja -j2 -C build
ninja -C build install
ldconfig
