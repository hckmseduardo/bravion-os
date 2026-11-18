#!/bin/bash
set -euo pipefail
umask 022
set -x
export MAKEFLAGS=-j4
cd /sources
archive='coreutils-9.10.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
patch -Np1 -i ../coreutils-9.10-i18n-1.patch

autoreconf -fv
automake -af
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr

make

make install

mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8

cd /sources
rm -rf "$source_dir"
