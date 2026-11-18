#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='automake-1.18.1.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1

make

make install

cd /sources
rm -rf "$source_dir"
