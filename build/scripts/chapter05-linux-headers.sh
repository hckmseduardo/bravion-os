#!/bin/bash
set -euo pipefail
set -x
cd "$LFS/sources"
archive='linux-6.18.10.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
make mrproper

make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr

cd "$LFS/sources"
rm -rf "$source_dir"
