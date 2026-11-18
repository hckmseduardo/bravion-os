#!/bin/bash
set -euo pipefail
umask 022
set -x
cd "$LFS/sources"
archive='xz-5.8.2.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.8.2

make

make DESTDIR=$LFS install

rm -v $LFS/usr/lib/liblzma.la

cd "$LFS/sources"
rm -rf "$source_dir"
