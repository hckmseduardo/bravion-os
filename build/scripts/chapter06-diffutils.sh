#!/bin/bash
set -euo pipefail
set -x
cd "$LFS/sources"
archive='diffutils-3.12.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            gl_cv_func_strcasecmp_works=y \
            --build=$(./build-aux/config.guess)

make

make DESTDIR=$LFS install

cd "$LFS/sources"
rm -rf "$source_dir"
