#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='bc-7.0.3.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r

make

make install

cd /sources
rm -rf "$source_dir"
