#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/pango-1.57.0
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Dintrospection=enabled -Ddocumentation=false -Dman-pages=false -Dbuild-testsuite=false -Dbuild-examples=false -Dlibthai=disabled -Dsysprof=disabled
ninja -j2 -C build
ninja -C build install
flock /run/desktop-ldconfig.lock ldconfig
