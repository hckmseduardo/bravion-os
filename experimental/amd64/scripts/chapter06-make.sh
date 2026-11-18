#!/bin/bash
set -euo pipefail
umask 022
set -x
cd "$LFS/sources"
archive='make-4.4.1.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make

make DESTDIR=$LFS install

cd "$LFS/sources"
rm -rf "$source_dir"
