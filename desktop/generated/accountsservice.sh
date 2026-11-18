#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/accountsservice-23.13.9
pkg-config --exists polkit-gobject-1 libsystemd gio-2.0 dbus-1
sed -i "/^subdir('tests')/d" meson.build
meson setup build --prefix=/usr --libdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release --wrap-mode=nofallback -Dadmin_group=wheel -Dintrospection=true -Dvapi=false -Ddocbook=false -Dgtk_doc=false
ninja -j2 -C build
ninja -j2 -C build install
ldconfig
