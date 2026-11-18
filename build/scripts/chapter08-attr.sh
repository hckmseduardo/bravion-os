#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='attr-2.5.2.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.5.2

make

make install

cd /sources
rm -rf "$source_dir"
