#!/bin/bash
set -euo pipefail
umask 022
r=/build/desktop-lfs
cp /build/lfs/sources/wpa_supplicant-2.11.tar.gz "$r/sources/"
mkdir -p "$r/sources/desktop-wpa"
tar -xf "$r/sources/wpa_supplicant-2.11.tar.gz" -C "$r/sources/desktop-wpa"
cat > "$r/sources/desktop-wpa/wpa_supplicant-2.11/wpa_supplicant/.config" <<'EOF'
CONFIG_BACKEND=file
CONFIG_CTRL_IFACE=y
CONFIG_CTRL_IFACE_DBUS_NEW=y
CONFIG_CTRL_IFACE_DBUS_INTRO=y
CONFIG_DEBUG_SYSLOG=y
CONFIG_DRIVER_NL80211=y
CONFIG_LIBNL32=y
CONFIG_IEEE80211W=y
CONFIG_SAE=y
CONFIG_SAE_PK=y
CONFIG_OWE=y
CONFIG_TLS=openssl
CONFIG_INTERNAL_LIBTOMMATH=y
CONFIG_INTERNAL_LIBTOMMATH_FAST=y
CONFIG_IPV6=y
CONFIG_READLINE=y
CFLAGS += -I/usr/include/libnl3
EOF
chroot "$r" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 /bin/bash -c 'umask 022; cd /sources/desktop-wpa/wpa_supplicant-2.11; make -j2 -C wpa_supplicant BINDIR=/usr/sbin LIBDIR=/usr/lib; make -C wpa_supplicant BINDIR=/usr/sbin LIBDIR=/usr/lib install; install -Dm644 wpa_supplicant/dbus/dbus-wpa_supplicant.conf /etc/dbus-1/system.d/wpa_supplicant.conf'
mkdir -p "$r/usr/share/dbus-1/system-services"
cat > "$r/usr/share/dbus-1/system-services/fi.w1.wpa_supplicant1.service" <<'EOF'
[D-BUS Service]
Name=fi.w1.wpa_supplicant1
Exec=/usr/sbin/wpa_supplicant -u -s -O /run/wpa_supplicant
User=root
SystemdService=wpa_supplicant.service
EOF
cat > "$r/etc/systemd/system/wpa_supplicant.service" <<'EOF'
[Unit]
Description=WPA supplicant D-Bus service for NetworkManager
After=dbus.service
[Service]
Type=dbus
BusName=fi.w1.wpa_supplicant1
ExecStart=/usr/sbin/wpa_supplicant -u -s -O /run/wpa_supplicant
[Install]
WantedBy=multi-user.target
EOF
touch "$r/desktop-done/wpa-dbus"
