#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libsecret-0.21.7
pkg-config --exists libgcrypt
meson setup build --prefix=/usr --libdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release --wrap-mode=nofallback -Dgtk_doc=false -Dmanpage=false -Dvapi=false -Dintrospection=true -Dcrypto=libgcrypt -Dtpm2=false -Dpam=false
ninja -j2 -C build
ninja -j2 -C build install
ldconfig
