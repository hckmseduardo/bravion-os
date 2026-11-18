#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/itstool-2.0.7
curl --fail -L https://www.linuxfromscratch.org/patches/blfs/13.0/itstool-2.0.7-lxml-1.patch -o /sources/itstool-2.0.7-lxml-1.patch
printf "%s  %s\n" 035a0d22bd1cf37a00357ebc096454e1eb8594f3ea54f8122e8e76fdced0cbec /sources/itstool-2.0.7-lxml-1.patch | sha256sum -c -
patch -Np1 -i /sources/itstool-2.0.7-lxml-1.patch
PYTHON=/usr/bin/python3 ./autogen.sh --prefix=/usr
make -j2
make install
ldconfig
