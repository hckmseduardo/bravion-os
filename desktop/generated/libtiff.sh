#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/tiff-4.7.1
cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -Dtiff-tests=OFF -Dtiff-tools=OFF -Dtiff-contrib=OFF -Dtiff-docs=OFF
cmake --build build -j2
cmake --install build
flock /run/desktop-ldconfig.lock ldconfig
