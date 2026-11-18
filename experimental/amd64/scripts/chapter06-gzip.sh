#!/bin/bash
set -euo pipefail
umask 022
set -x
cd "$LFS/sources"
archive='gzip-1.14.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr --host=$LFS_TGT

make

make DESTDIR=$LFS install

cd "$LFS/sources"
rm -rf "$source_dir"
