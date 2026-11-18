#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/pyparsing-3.3.3
python3 -m pip install --no-index --no-deps --no-build-isolation --no-cache-dir .
flock /run/desktop-ldconfig.lock ldconfig
