#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/p11-kit-0.26.2
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Dtrust_paths=/etc/pki/anchors -Dgtk_doc=false -Dman=false
ninja -j2 -C build
ninja -C build install
ldconfig
