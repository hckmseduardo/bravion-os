#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/git-2.53.0
make -j2 prefix=/usr NO_TCLTK=YesPlease all
make prefix=/usr NO_TCLTK=YesPlease install
ldconfig
