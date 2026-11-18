#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/pulseaudio-17.0
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Ddaemon=false -Ddatabase=simple -Dbluez5=disabled -Ddoxygen=false -Dtests=false -Dman=false
ninja -j2 -C build
ninja -C build install
ldconfig
