#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/greetd-0.10.3
test -f /usr/include/security/pam_appl.h
export CARGO_TARGET_DIR=/sources/cosmic-target CARGO_BUILD_JOBS=1 CARGO_INCREMENTAL=0 CARGO_PROFILE_RELEASE_DEBUG=0 CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_INCREMENTAL=false
cargo build --locked --release -j1 -p greetd
install -Dm755 "$CARGO_TARGET_DIR/release/greetd" /usr/bin/greetd
flock /run/desktop-ldconfig.lock ldconfig
