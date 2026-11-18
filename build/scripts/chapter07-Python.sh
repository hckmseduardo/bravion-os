#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='Python-3.14.3.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr       \
            --enable-shared     \
            --without-ensurepip \
            --without-static-libpython

make

make install

cd /sources
rm -rf "$source_dir"
