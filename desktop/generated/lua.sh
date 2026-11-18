#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/lua-5.4.8
curl --fail -L https://www.linuxfromscratch.org/patches/blfs/13.0/lua-5.4.8-shared_library-1.patch -o /sources/lua-5.4.8-shared_library-1.patch
printf "%s  %s\n" 44324a802822f0a35d095aaad2f5f58fa7b1821ae87ae44dbcfc8a23fcd2e67e /sources/lua-5.4.8-shared_library-1.patch | sha256sum -c -
patch -Np1 -i /sources/lua-5.4.8-shared_library-1.patch
make -j2 linux
make INSTALL_TOP=/usr INSTALL_DATA="cp -d" INSTALL_MAN=/usr/share/man/man1 TO_LIB="liblua.so liblua.so.5.4 liblua.so.5.4.8" install
install -d /usr/lib/pkgconfig
cat > /usr/lib/pkgconfig/lua.pc <<'EOF'
prefix=/usr
exec_prefix=${prefix}
libdir=${prefix}/lib
includedir=${prefix}/include
Name: Lua
Description: Lua programming language
Version: 5.4.8
Libs: -L${libdir} -llua -lm -ldl
Cflags: -I${includedir}
EOF

ldconfig
