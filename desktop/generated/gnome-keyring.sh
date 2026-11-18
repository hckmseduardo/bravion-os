#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/gnome-keyring-48.0
pkg-config --exists gcr-base-3 gck-1
sed -i 's:"/desktop:"/org:' schema/*.xml
meson setup build --prefix=/usr --libdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release --wrap-mode=nofallback -Dmanpage=false -Dssh-agent=false -Dselinux=disabled -Dsystemd=enabled -Dpam=true -Ddebug-mode=false
ninja -j2 -C build
ninja -j2 -C build install
glib-compile-schemas /usr/share/glib-2.0/schemas
flock /run/desktop-ldconfig.lock ldconfig
