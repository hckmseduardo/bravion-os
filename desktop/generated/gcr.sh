#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/gcr-3.41.2
pkg-config --exists gtk+-3.0 p11-kit-1 libgcrypt libsecret-1
sed '/ssh.add/d; /ssh.agent/d' -i meson.build
sed -i 's:"/desktop:"/org:' schema/*.xml
meson setup build --prefix=/usr --libdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release --wrap-mode=nofallback -Dgtk_doc=false -Dssh_agent=false -Dgtk=true -Dintrospection=false -Dsystemd=enabled
ninja -j2 -C build
ninja -j2 -C build install
flock /run/desktop-ldconfig.lock ldconfig
