#!/bin/bash
set -euo pipefail
umask 022
set -x
cd "$LFS/sources"
archive='sed-4.9.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess)

make

make DESTDIR=$LFS install

cd "$LFS/sources"
rm -rf "$source_dir"
