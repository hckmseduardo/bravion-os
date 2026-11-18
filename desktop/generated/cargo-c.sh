#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/cargo-c-0.10.20
curl -fL https://github.com/lu-zero/cargo-c/releases/download/v0.10.20/Cargo.lock -o Cargo.lock
echo '021854be3ef40003288171a6c5c65181  Cargo.lock' | md5sum -c -
export LIBSQLITE3_SYS_USE_PKG_CONFIG=1
cargo build --release --locked -j2
install -m755 target/release/cargo-capi target/release/cargo-cbuild target/release/cargo-cinstall target/release/cargo-ctest /usr/bin/
flock /run/desktop-ldconfig.lock ldconfig
