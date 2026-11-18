#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='gperf-3.3.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3

make

make install

cd /sources
rm -rf "$source_dir"
