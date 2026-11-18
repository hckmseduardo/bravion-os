#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/dconf-0.49.0
meson setup build --prefix=/usr --libdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release --wrap-mode=default -Dbash_completion=false -Dman=false -Dgtk_doc=false -Dvapi=false
ninja -j2 -C build
ninja -j2 -C build install
gio-querymodules /usr/lib/gio/modules
ldconfig
