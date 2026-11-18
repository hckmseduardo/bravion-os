#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/pipewire-1.6.0
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Dsession-managers=[] -Dalsa=enabled -Dpipewire-alsa=enabled -Dlibsystemd=enabled -Dlogind=enabled -Dsystemd-user-service=enabled -Ddocs=disabled -Dman=disabled -Dtests=disabled -Dexamples=disabled -Dbluez5=disabled -Dgstreamer=disabled -Dlibpulse=disabled
ninja -j2 -C build
ninja -C build install
ldconfig
