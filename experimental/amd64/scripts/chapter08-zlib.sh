#!/bin/bash
set -euo pipefail
umask 022
set -x
export MAKEFLAGS=-j4
cd /sources
archive='zlib-1.3.2.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr

make

make install

rm -fv /usr/lib/libz.a

cd /sources
rm -rf "$source_dir"
