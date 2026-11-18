#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/liberation-fonts-ttf-2.1.5
install -d -m755 /usr/share/fonts/liberation /usr/share/doc/liberation-fonts-2.1.5
install -m644 *.ttf /usr/share/fonts/liberation/
install -m644 LICENSE /usr/share/doc/liberation-fonts-2.1.5/
fc-cache -f
flock /run/desktop-ldconfig.lock ldconfig
