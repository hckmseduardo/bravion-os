#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libdrm-2.4.131
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Dintel=disabled -Dradeon=disabled -Damdgpu=disabled -Dnouveau=disabled -Dvmwgfx=disabled -Dfreedreno=disabled -Dtegra=disabled -Detnaviv=disabled -Dexynos=disabled -Dvc4=enabled -Dtests=false
ninja -j2 -C build
ninja -C build install
ldconfig
