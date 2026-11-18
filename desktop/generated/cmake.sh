#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/cmake-4.2.3
./bootstrap --prefix=/usr --parallel=2 -- -DCMAKE_USE_OPENSSL=ON -DCMAKE_BUILD_TYPE=Release
make -j2
make install
ldconfig
