#!/bin/bash
set -euo pipefail
umask 022
set -x
export MAKEFLAGS=${MAKEFLAGS:--j1}
cd /sources
md5sum -c blfs-md5sums
printf '%s  %s\n' 9ae44872090cf2f06b3cf9ff147e7f16f309671340763ed2f99248398ae29d5b openssh-10.6p2.tar.gz | sha256sum -c -
sha256sum -c openssl-3.5.9.tar.gz.sha256
build_package() {
    tar -xf "$1"
    cd "$2"
}
build_package libnl-3.12.0.tar.gz libnl-3.12.0
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make install
cd /sources
rm -rf libnl-3.12.0
build_package iw-6.17.tar.xz iw-6.17
sed -i '/INSTALL.*gz/s/.gz//' Makefile
make
make PREFIX=/usr install
cd /sources
rm -rf iw-6.17
build_package wpa_supplicant-2.11.tar.gz wpa_supplicant-2.11
cat > wpa_supplicant/.config <<'EOF'
CONFIG_BACKEND=file
CONFIG_CTRL_IFACE=y
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
make -C wpa_supplicant BINDIR=/usr/sbin LIBDIR=/usr/lib
make -C wpa_supplicant BINDIR=/usr/sbin LIBDIR=/usr/lib install
cd /sources
rm -rf wpa_supplicant-2.11
build_package openssh-10.6p2.tar.gz openssh-10.6p2
install -d -m700 /var/lib/sshd
# BEGIN SSHD ACCOUNT
if ! getent group sshd >/dev/null; then
 if getent group 50 >/dev/null; then echo 'GID 50 belongs to another group' >&2; exit 1; fi
 groupadd -g 50 sshd
fi
[[ $(getent group sshd | cut -d: -f3) == 50 ]] || { echo 'Unexpected sshd group ID' >&2; exit 1; }
if ! id sshd >/dev/null 2>&1; then
 if getent passwd 50 >/dev/null; then echo 'UID 50 belongs to another account' >&2; exit 1; fi
 useradd -r -u 50 -g sshd -d /var/lib/sshd -s /usr/bin/false sshd
fi
[[ $(id -u sshd) == 50 && $(id -g sshd) == 50 && $(getent passwd sshd | cut -d: -f6) == /var/lib/sshd && $(getent passwd sshd | cut -d: -f7) == /usr/bin/false ]] || { echo 'Unexpected sshd account configuration' >&2; exit 1; }
# END SSHD ACCOUNT
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-privsep-path=/var/lib/sshd --with-default-path=/usr/bin:/usr/sbin --with-superuser-path=/usr/sbin:/usr/bin --with-pid-dir=/run
make
make install
cd /sources
rm -rf openssh-10.6p2
build_package sudo-1.9.17p2.tar.gz sudo-1.9.17p2
./configure --prefix=/usr --libexecdir=/usr/lib --with-secure-path=/usr/sbin:/usr/bin --with-all-insults --with-env-editor --with-passprompt='[sudo] password for %p: '
make
make install
cd /sources
rm -rf sudo-1.9.17p2
ldconfig
build_package curl-8.23.0.tar.xz curl-8.23.0
./configure --prefix=/usr --with-openssl --disable-static --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt --without-libpsl --without-libidn2 --without-brotli --without-zstd --disable-ldap --disable-ldaps
make
make install
cd /sources
rm -rf curl-8.23.0
ldconfig
build_package dosfstools-4.2.tar.gz dosfstools-4.2
./configure --prefix=/usr --enable-compat-symlinks --mandir=/usr/share/man
make
make check
make install
cd /sources
rm -rf dosfstools-4.2
