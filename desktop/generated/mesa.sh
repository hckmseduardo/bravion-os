#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/mesa-25.3.5
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Dplatforms=x11,wayland -Dgallium-drivers=vc4,v3d,virgl,softpipe -Dvulkan-drivers=broadcom -Dllvm=disabled -Ddraw-use-llvm=false -Dglvnd=enabled -Dglx=dri -Degl=enabled -Dgbm=enabled -Dgles1=enabled -Dgles2=enabled -Dgallium-va=disabled -Dvalgrind=disabled -Dlibunwind=disabled -Dbuild-tests=false -Dvideo-codecs=all
ninja -j2 -C build
ninja -C build install
ldconfig
