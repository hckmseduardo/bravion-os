#!/bin/bash
set -euo pipefail
umask 022
set -x
export MAKEFLAGS=-j4
cd /sources
archive='acl-2.3.2.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/acl-2.3.2

make

make install

cd /sources
rm -rf "$source_dir"
