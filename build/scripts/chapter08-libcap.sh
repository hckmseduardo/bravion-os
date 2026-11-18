#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='libcap-2.77.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
sed -i '/install -m.*STA/d' libcap/Makefile

make prefix=/usr lib=lib

make prefix=/usr lib=lib install

cd /sources
rm -rf "$source_dir"
