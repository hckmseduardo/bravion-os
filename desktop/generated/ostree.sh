#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/libostree-2026.7
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-curl --without-soup --without-soup3 --with-gpgme --with-libarchive --with-libsystemd --without-selinux --without-avahi --disable-gtk-doc --disable-man
make -j2
make install
ldconfig
