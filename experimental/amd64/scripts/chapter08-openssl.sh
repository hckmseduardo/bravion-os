#!/bin/bash
set -euo pipefail
umask 022
set -x
export MAKEFLAGS=-j4
cd /sources
archive='openssl-3.5.9.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic

make

sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install

mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.5.9

cp -vfr doc/* /usr/share/doc/openssl-3.5.9

cd /sources
rm -rf "$source_dir"
