#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/gtk-3.24.51
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Dx11_backend=true -Dwayland_backend=true -Dbroadway_backend=false -Dintrospection=true -Dgtk_doc=false -Dman=false -Ddemos=false -Dexamples=false -Dtests=false -Dinstalled_tests=false -Dprint_backends=file,cups
ninja -j2 -C build
ninja -C build install
gtk-query-immodules-3.0 --update-cache
glib-compile-schemas /usr/share/glib-2.0/schemas
flock /run/desktop-ldconfig.lock ldconfig
