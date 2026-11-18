#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/shared-mime-info-2.4
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Dbuild-tools=true -Dupdate-mimedb=true -Dbuild-tests=false
ninja -j2 -C build
ninja -C build install
flock /run/desktop-ldconfig.lock ldconfig
