#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/gsettings-desktop-schemas-49.1
sed -i -r 's:"(/system):"/org/gnome\1:g' schemas/*.in
meson setup build --prefix=/usr --libdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release --wrap-mode=nofallback 
ninja -j2 -C build
ninja -j2 -C build install
glib-compile-schemas /usr/share/glib-2.0/schemas
ldconfig
