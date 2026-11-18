#!/bin/bash
# Run INSIDE native LFS chroot AFTER cosmic-build.sh and existing console image setup.
# Creates configuration only; does not start any service inside the build chroot.
set -Eeuo pipefail
export PATH=/usr/bin:/usr/sbin:/bin:/sbin
[[ $(id -u) == 0 && -f /etc/lfs-release ]] || { echo 'Run inside LFS chroot as root' >&2; exit 1; }
src=/sources/cosmic-epoch/cosmic-greeter
for binary in greetd cosmic-comp cosmic-session cosmic-greeter cosmic-greeter-daemon dbus-run-session; do
    command -v "$binary" >/dev/null || { echo "Missing $binary" >&2; exit 1; }
done
[[ -f /etc/systemd/system/pi-firstboot.service && -x /usr/sbin/pi-setup ]]
[[ -f /usr/lib/security/pam_systemd.so || -f /usr/lib64/security/pam_systemd.so ]]
[[ -f /etc/pam.d/system-auth ]] || { echo 'Install BLFS Linux-PAM system-auth stack first' >&2; exit 1; }
install -d /etc/greetd /etc/pam.d /etc/systemd/system /var/lib/pi-lfs
install -m644 "$src/cosmic-greeter.toml" /etc/greetd/cosmic-greeter.toml
install -m644 "$src/debian/cosmic-greeter-daemon.service" /etc/systemd/system/cosmic-greeter-daemon.service
# COSMIC greeter locks/unlocks through PAM; greetd's configured PAM service is cosmic-greeter.
# Use the image's Linux-PAM stack; Debian common-* includes do not exist on LFS.
cat > /etc/pam.d/cosmic-greeter <<'PAM'
auth requisite pam_nologin.so
auth required pam_succeed_if.so user != root quiet_success
auth include system-auth
account include system-account
password include system-password
session required pam_limits.so
session required pam_env.so conffile=/etc/security/cosmic-env.conf readenv=0 user_readenv=0
session include system-session
PAM
# greetd's own initial greeter session needs PAM/logind as well.
cat > /etc/pam.d/greetd <<'PAM'
auth include system-auth
account include system-account
session required pam_env.so conffile=/etc/security/cosmic-env.conf readenv=0 user_readenv=0
session include system-session
PAM
# greetd 0.10.3 uses greetd-greeter for default_session unless explicitly configured.
# Its authentication is skipped by greetd for the fixed system greeter account.
cat > /etc/pam.d/greetd-greeter <<'PAM'
auth required pam_permit.so
account include system-account
session required pam_env.so conffile=/etc/security/cosmic-env.conf readenv=0 user_readenv=0
session include system-session
PAM
# pam_systemd in system-session must see the graphical type before registration.
install -d /etc/security
cat > /etc/security/cosmic-env.conf <<'PAMENV'
XDG_SESSION_TYPE DEFAULT=wayland OVERRIDE=wayland
XDG_CURRENT_DESKTOP DEFAULT=COSMIC OVERRIDE=COSMIC
XDG_SESSION_DESKTOP DEFAULT=COSMIC OVERRIDE=COSMIC
XDG_DATA_DIRS DEFAULT=/usr/local/share:/usr/share:/var/lib/flatpak/exports/share:@{HOME}/.local/share/flatpak/exports/share
PAMENV
# Optional keyring module; no credentials or account/password are baked into the image.
if [[ -f /usr/lib/security/pam_gnome_keyring.so || -f /usr/lib64/security/pam_gnome_keyring.so ]]; then
    sed -i '/^auth include system-auth/a auth optional pam_gnome_keyring.so' /etc/pam.d/cosmic-greeter
    printf '%s\n' 'session optional pam_gnome_keyring.so auto_start' >> /etc/pam.d/cosmic-greeter
fi
if command -v systemd-sysusers >/dev/null; then
    systemd-sysusers /usr/lib/sysusers.d/cosmic-greeter.conf
else
    # Equivalent to upstream u/m entries on LFS builds configured without sysusers.
    getent group cosmic-greeter >/dev/null || groupadd -r cosmic-greeter
    getent passwd cosmic-greeter >/dev/null || useradd -r -g cosmic-greeter -d /var/lib/cosmic-greeter -s /usr/sbin/nologin -c 'Cosmic Greeter Account' cosmic-greeter
    usermod -a -G video cosmic-greeter
fi
systemd-tmpfiles --create /usr/lib/tmpfiles.d/cosmic-greeter.conf
cat > /etc/systemd/system/cosmic-greeter.service <<'UNIT'
[Unit]
Description=COSMIC graphical login after console account setup
Requires=pi-firstboot.service
Wants=cosmic-greeter-daemon.service
After=pi-firstboot.service systemd-user-sessions.service cosmic-greeter-daemon.service
Conflicts=getty@tty1.service
After=getty@tty1.service
[Service]
Type=simple
# Evaluated after dependencies; a failed/incomplete wizard must never expose login.
ExecStartPre=/usr/bin/test -f /var/lib/pi-lfs/setup-complete
ExecStart=/usr/bin/greetd --config /etc/greetd/cosmic-greeter.toml
IgnoreSIGPIPE=no
SendSIGHUP=yes
TimeoutStopSec=30s
KeyringMode=shared
Restart=on-failure
RestartSec=3
[Install]
Alias=display-manager.service
WantedBy=graphical.target
UNIT
# The console wizard remains foreground on tty1 until account setup succeeds.
install -d /etc/systemd/system/pi-firstboot.service.d
cat > /etc/systemd/system/pi-firstboot.service.d/cosmic.conf <<'UNIT'
[Unit]
Before=cosmic-greeter.service
UNIT
# Second VT stays available for recovery; no autologin.
systemctl enable getty@tty2.service dbus.socket cosmic-greeter.service
systemctl set-default graphical.target
for service in NetworkManager bluetooth upower accounts-daemon; do
    if [[ -f /usr/lib/systemd/system/$service.service || -f /etc/systemd/system/$service.service ]]; then systemctl enable "$service.service"; fi
done
# PipeWire/WirePlumber use supplied user service presets. Do not start a system PipeWire.
for service in pipewire.socket pipewire-pulse.socket wireplumber.service; do
    if [[ -f /usr/lib/systemd/user/$service || -f /etc/systemd/user/$service ]]; then systemctl --global enable "$service"; fi
done
# Signed Flatpak remotes and the preinstalled browser are provisioned by the next build step.
# This edition contains only native Wayland applications; explicitly suppress Xwayland.
sed -i 's@/usr/bin/cosmic-session$@/usr/bin/cosmic-session cosmic-comp --no-xwayland@' /usr/bin/start-cosmic
grep -q 'cosmic-session cosmic-comp --no-xwayland' /usr/bin/start-cosmic
sed -i 's/exec cosmic-comp cosmic-greeter/exec cosmic-comp --no-xwayland cosmic-greeter/' /usr/bin/cosmic-greeter-start
grep -q 'cosmic-comp --no-xwayland cosmic-greeter' /usr/bin/cosmic-greeter-start
glib-compile-schemas /usr/share/glib-2.0/schemas
ldconfig
systemd-analyze verify --man=no /etc/systemd/system/cosmic-greeter.service \
 /etc/systemd/system/cosmic-greeter-daemon.service /etc/systemd/system/pi-firstboot.service
