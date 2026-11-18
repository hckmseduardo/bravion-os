#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/cups-2.4.16
sed -i '/& ipp->prev)/s/prev/& \&\& ipp->prev->next == *attr/' cups/ipp.c
./configure --prefix=/usr --libdir=/usr/lib --with-components=libcups --with-tls=openssl --disable-static --disable-gssapi --disable-libusb --disable-dbus --disable-pam --with-dnssd=no
make -j2
make install
flock /run/desktop-ldconfig.lock ldconfig
