#!/bin/bash
set -euo pipefail
set -x
cd /sources
archive='flit_core-3.12.0.tar.gz'
source_dir=$(tar -tf "$archive" | sed -n '1s@/.*@@p')
rm -rf "$source_dir"
tar -xf "$archive"
cd "$source_dir"
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --no-index --find-links dist flit_core

cd /sources
rm -rf "$source_dir"
