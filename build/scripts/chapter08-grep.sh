#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='grep-3.12.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
sed -i "s/echo/#echo/" src/egrep.sh

./configure --prefix=/usr

make

make install

cd /sources
rm -rf "$source_dir"
