#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='bison-3.8.2.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr \
            --docdir=/usr/share/doc/bison-3.8.2

make

make install

cd /sources
rm -rf "$source_dir"
