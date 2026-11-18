#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='lz4-1.10.0.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
make BUILD_STATIC=no PREFIX=/usr

make BUILD_STATIC=no PREFIX=/usr install

cd /sources
rm -rf "$source_dir"
