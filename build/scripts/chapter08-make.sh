#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='make-4.4.1.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr

make

make install

cd /sources
rm -rf "$source_dir"
