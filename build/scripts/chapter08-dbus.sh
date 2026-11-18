#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='dbus-1.16.2.tar.xz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
mkdir build
cd    build

meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..

ninja

ninja install

ln -sfv /etc/machine-id /var/lib/dbus

cd /sources
rm -rf "$source_dir"
