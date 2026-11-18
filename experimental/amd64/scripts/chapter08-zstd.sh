#!/bin/bash
set -euo pipefail
umask 022
set -x
export MAKEFLAGS=-j4
cd /sources
archive='zstd-1.5.7.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
make prefix=/usr

make prefix=/usr install

rm -v /usr/lib/libzstd.a

cd /sources
rm -rf "$source_dir"
