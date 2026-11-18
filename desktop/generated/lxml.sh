#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/lxml-6.0.2
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD
pip3 install --no-index --find-links dist --no-user lxml
ldconfig
