#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 NINJAFLAGS=-j2
cd /sources/dbus-1.16.2
rm -f /etc/machine-id
dbus-uuidgen --ensure=/etc/machine-id
getent group messagebus >/dev/null || groupadd -g 18 messagebus
id messagebus >/dev/null 2>&1 || useradd -c "D-Bus Message Daemon User" -d /run/dbus -u 18 -g messagebus -s /bin/false messagebus
meson setup build --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Dsystemd=enabled -Dxml_docs=disabled -Dducktype_docs=disabled
ninja -j2 -C build
ninja -C build install
chown root:messagebus /usr/libexec/dbus-daemon-launch-helper
chmod 4750 /usr/libexec/dbus-daemon-launch-helper
dbus-uuidgen --ensure=/etc/machine-id
ldconfig
