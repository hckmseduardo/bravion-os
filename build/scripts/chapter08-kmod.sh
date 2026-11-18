#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='kmod-34.2.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
mkdir -p build
cd       build

meson setup --prefix=/usr ..    \
            --buildtype=release \
            -D manpages=false

ninja

ninja install

cd /sources
rm -rf "$source_dir"
