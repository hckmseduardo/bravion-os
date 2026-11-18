#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='texinfo-7.2.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
sed 's/! $output_file eq/$output_file ne/' -i tp/Texinfo/Convert/*.pm

./configure --prefix=/usr

make

make install

cd /sources
rm -rf "$source_dir"
