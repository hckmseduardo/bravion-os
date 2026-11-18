#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/gst-plugins-base-1.28.1
meson setup build --prefix=/usr --libdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release --wrap-mode=nofallback --auto-features=disabled -Ddoc=disabled -Dtests=disabled -Dexamples=disabled -Dintrospection=enabled -Dtools=enabled -Dapp=enabled -Daudioconvert=enabled -Daudioresample=enabled -Dvolume=enabled -Dplayback=enabled -Dtypefind=enabled -Dgio=enabled -Drawparse=enabled -Dogg=enabled -Dvorbis=enabled -Dorc=disabled -Dgl=disabled -Dx11=disabled -Dxshm=disabled -Dxvideo=disabled
ninja -j2 -C build
ninja -C build install
flock /run/desktop-ldconfig.lock ldconfig
