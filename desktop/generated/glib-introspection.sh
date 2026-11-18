#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/glib-2.86.4
cd ../glib-2.86.4
meson configure build -Dintrospection=enabled
ninja -j2 -C build
ninja -C build install
ldconfig
