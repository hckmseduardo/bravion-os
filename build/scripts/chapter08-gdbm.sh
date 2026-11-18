#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='gdbm-1.26.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat

make

make install

cd /sources
rm -rf "$source_dir"
