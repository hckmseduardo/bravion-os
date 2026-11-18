#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='gettext-1.0.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-1.0

make

make install
chmod -v 0755 /usr/lib/preloadable_libintl.so

cd /sources
rm -rf "$source_dir"
