#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='mpc-1.3.1.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.3.1

make
make html

make install
make install-html

cd /sources
rm -rf "$source_dir"
