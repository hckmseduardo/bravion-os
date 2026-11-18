#!/bin/bash
set -euo pipefail
umask 022
export PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2 LC_ALL=C.UTF-8
install -dm755 /etc/pam.d
for p in auth account session; do
 printf '%s\n' "$p required pam_unix.so" > "/etc/pam.d/system-$p"
done
cat > /etc/pam.d/system-password <<'EOF'
password required pam_unix.so yescrypt shadow try_first_pass
EOF
cat > /etc/pam.d/other <<'EOF'
auth required pam_warn.so
auth required pam_deny.so
account required pam_warn.so
account required pam_deny.so
password required pam_warn.so
password required pam_deny.so
session required pam_warn.so
session required pam_deny.so
EOF
# Build dedicated trees; leave other pipelines' extraction directories untouched.
install -dm755 /sources/pam-stack-systemd /sources/pam-stack-shadow
tar -xf /sources/shadow-4.19.3.tar.xz --strip-components=1 -C /sources/pam-stack-shadow
cd /sources/pam-stack-shadow
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \;
sed -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD YESCRYPT@' -e 's@/var/spool/mail@/var/mail@' -e '/PATH=/{s@/sbin:@@;s@/bin:@@}' -i etc/login.defs
./configure --sysconfdir=/etc --disable-static --without-libbsd --with-bcrypt --with-yescrypt --with-group-name-max-length=32
make -j2
make exec_prefix=/usr pamddir= install
make -C man install-man
cp -a /etc/login.defs /etc/login.defs.before-pam
for setting in FAIL_DELAY FAILLOG_ENAB LASTLOG_ENAB MAIL_CHECK_ENAB OBSCURE_CHECKS_ENAB PORTTIME_CHECKS_ENAB QUOTAS_ENAB CONSOLE MOTD_FILE FTMP_FILE NOLOGINS_FILE ENV_HZ PASS_MIN_LEN SU_WHEEL_ONLY PASS_CHANGE_TRIES PASS_ALWAYS_WARN CHFN_AUTH ENCRYPT_METHOD ENVIRON_FILE; do
 sed -i "s/^${setting}/# &/" /etc/login.defs
done
cat > /etc/pam.d/login <<'EOF'
auth optional pam_faildelay.so delay=3000000
auth requisite pam_nologin.so
auth include system-auth
account required pam_access.so
account include system-account
session required pam_env.so
session required pam_limits.so
session include system-session
password include system-password
EOF
cat > /etc/pam.d/passwd <<'EOF'
password include system-password
EOF
cat > /etc/pam.d/su <<'EOF'
auth sufficient pam_rootok.so
auth include system-auth
account include system-account
session required pam_env.so
session include system-session
EOF
cp /etc/pam.d/su /etc/pam.d/su-l
cat > /etc/pam.d/chpasswd <<'EOF'
auth sufficient pam_rootok.so
auth include system-auth
account include system-account
password include system-password
EOF
cp /etc/pam.d/chpasswd /etc/pam.d/newusers
cat > /etc/pam.d/chage <<'EOF'
auth sufficient pam_rootok.so
auth include system-auth
account include system-account
EOF
for program in chfn chgpasswd chsh groupadd groupdel groupmems groupmod useradd userdel usermod; do
 install -m644 /etc/pam.d/chage "/etc/pam.d/$program"
done
# Keep the existing sudo policy and binary; install service only if absent.
if ! test -f /etc/pam.d/sudo; then
 cat > /etc/pam.d/sudo <<'EOF'
auth include system-auth
account include system-account
password include system-password
session include system-session
EOF
fi
for legacy in /etc/login.access /etc/limits; do
 if test -f "$legacy"; then mv "$legacy" "$legacy.before-pam"; fi
done
cd /sources/pam-stack-systemd
tar -xf /sources/systemd-259.1.tar.gz --strip-components=1
sed -i -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
rm -f /usr/lib/systemd/system/systemd-update-utmp-runlevel.service
meson setup build --prefix=/usr --libdir=lib --buildtype=release -Ddefault-dnssec=no -Dfirstboot=false -Dinstall-tests=false -Dldconfig=false -Dman=disabled -Dsysusers=false -Drpmmacrosdir=no -Dhomed=disabled -Dmode=release -Dpam=enabled -Dpamconfdir=/etc/pam.d -Ddev-kvm-mode=0660 -Dnobody-group=nogroup -Dsysupdate=disabled -Dukify=disabled -Dbootloader=disabled -Ddocdir=/usr/share/doc/systemd-259.1
ninja -j2 -C build
ninja -C build install
cat >> /etc/pam.d/system-session <<'EOF'
session required pam_loginuid.so
session optional pam_systemd.so
EOF
cat > /etc/pam.d/systemd-user <<'EOF'
account required pam_access.so
account include system-account
session required pam_env.so
session required pam_limits.so
session required pam_loginuid.so
session optional pam_keyinit.so force revoke
session optional pam_systemd.so
auth required pam_deny.so
password required pam_deny.so
EOF
ldconfig
# Meaningful install/link checks (no live systemd daemon in Docker).
test -f /usr/lib/security/pam_systemd.so
ldd /usr/lib/security/pam_systemd.so | tee /desktop-logs/pam-systemd-links.txt
! grep -q 'not found' /desktop-logs/pam-systemd-links.txt
ldd /usr/bin/su | tee /desktop-logs/shadow-su-links.txt
grep -q libpam /desktop-logs/shadow-su-links.txt
! grep -q 'not found' /desktop-logs/shadow-su-links.txt
for binary in /usr/bin/su /usr/bin/passwd /usr/bin/sudo /usr/sbin/unix_chkpwd; do
 test -u "$binary"
 test "$(stat -c %u "$binary")" = 0
 stat -c '%u %g %a %n' "$binary"
done
for unit in systemd-logind.service user@.service; do
 test -f "/usr/lib/systemd/system/$unit"
done
/usr/lib/systemd/systemd --version
systemd-analyze verify /usr/lib/systemd/system/systemd-logind.service /usr/lib/systemd/system/user@.service
# Keep SSH password policy, root password, preset state, and ownership untouched.
touch /desktop-done/pam-stack
