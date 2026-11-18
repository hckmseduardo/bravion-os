#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/nss-3.120.1
curl -fL https://www.linuxfromscratch.org/patches/blfs/13.0/nss-standalone-1.patch -o ../nss-standalone-1.patch
echo '87bb1af0b11fd41311b9899187f6e4b3fca9940651123c7bc836ec7497d2da84  ../nss-standalone-1.patch' | sha256sum -c -
patch -Np1 -i ../nss-standalone-1.patch
cd nss
make -j2 BUILD_OPT=1 USE_64=1 NSPR_INCLUDE_DIR=/usr/include/nspr USE_SYSTEM_ZLIB=1 ZLIB_LIBS=-lz NSS_ENABLE_WERROR=0 NSS_USE_SYSTEM_SQLITE=1
cd ../dist
install -m755 Linux*/lib/*.so /usr/lib
install -m644 Linux*/lib/*.chk Linux*/lib/libcrmf.a /usr/lib
install -d -m755 /usr/include/nss
cp -RL public/nss/* private/nss/* /usr/include/nss
install -m755 Linux*/bin/certutil Linux*/bin/nss-config Linux*/bin/pk12util /usr/bin
install -m644 Linux*/lib/pkgconfig/nss.pc /usr/lib/pkgconfig
flock /run/desktop-ldconfig.lock ldconfig
