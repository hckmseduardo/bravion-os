#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='libffi-3.5.2.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr    \
            --disable-static \
            --with-gcc-arch=native

make

make install

cd /sources
rm -rf "$source_dir"
