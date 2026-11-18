#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='findutils-4.10.0.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr --localstatedir=/var/lib/locate

make

make install

cd /sources
rm -rf "$source_dir"
