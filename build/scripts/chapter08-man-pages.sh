#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='man-pages-6.17.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
rm -v man3/crypt*

make -R GIT=false prefix=/usr install

cd /sources
rm -rf "$source_dir"
