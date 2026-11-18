#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='expect5.45.4.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
# Expect bundles 2003 GNU config scripts that do not recognize AArch64.
# Reuse modern scripts from the already pinned and verified Binutils archive.
for config in config.guess config.sub; do
 tar -xOf /sources/binutils-2.46.0.tar.xz "binutils-2.46.0/$config" > "tclconfig/$config"
done
python3 -c 'from pty import spawn; spawn(["echo", "ok"])'

patch -Np1 -i ../expect-5.45.4-gcc15-1.patch

./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --disable-rpath         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include

make

make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib

cd /sources
rm -rf "$source_dir"
