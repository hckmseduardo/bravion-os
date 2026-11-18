#!/bin/bash
set -euo pipefail
umask 022
set -x
export MAKEFLAGS=-j4
cd /sources
archive='tar-1.35.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr

make

make install
make -C doc install-html docdir=/usr/share/doc/tar-1.35

cd /sources
rm -rf "$source_dir"
