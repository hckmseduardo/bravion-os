#!/bin/bash
set -euo pipefail
set -x
root=/build/lfs
install -Dm755 /workspace/build/pi_setup.py "$root/usr/sbin/pi-setup"
mkdir -p "$root"/etc/{systemd/system,systemd/network,wpa_supplicant,sudoers.d,ssh,modprobe.d} "$root"/var/lib/pi-lfs "$root"/boot/firmware "$root"/usr/share/licenses/pi-lfs/ca-certificates
cat > "$root/etc/os-release" <<'EOF'
NAME="Pi LFS"
PRETTY_NAME="Pi LFS 0.1 (Raspberry Pi 4 USB)"
ID=pi-lfs
ID_LIKE=lfs
VERSION_ID=0.1
EOF
echo pi-lfs > "$root/etc/hostname"
cat > "$root/etc/profile" <<'EOF'
export PATH=/usr/local/bin:/usr/bin:/usr/sbin
export LANG=C.UTF-8
umask 022
case $- in
    *i*) PS1='[\u@\h \W]\$ ' ;;
esac
EOF
echo 'Pi LFS 0.1 — Raspberry Pi 4 USB edition' > "$root/etc/issue"
cat > "$root/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 pi-lfs
::1 localhost
EOF
cat > "$root/etc/fstab" <<'EOF'
PARTUUID=4c465350-02 / ext4 defaults,noatime 0 1
PARTUUID=4c465350-01 /boot/firmware vfat defaults,umask=0077 0 2
EOF
cat > "$root/boot/firmware/config.txt" <<'EOF'
[all]
arm_64bit=1
kernel=kernel8.img
enable_uart=1
disable_overscan=1
dtoverlay=vc4-kms-v3d
max_framebuffers=2
EOF
printf '%s\n' 'console=serial0,115200 console=tty1 root=PARTUUID=4c465350-02 rootfstype=ext4 rootwait rw net.ifnames=0' > "$root/boot/firmware/cmdline.txt"
cat > "$root/etc/systemd/network/10-ethernet.network" <<'EOF'
[Match]
Name=eth* en*
[Network]
DHCP=yes
IPv6AcceptRA=yes
[DHCPv4]
RouteMetric=100
EOF
cat > "$root/etc/systemd/network/20-wifi.network" <<'EOF'
[Match]
Name=wl*
[Network]
DHCP=yes
IPv6AcceptRA=yes
[DHCPv4]
RouteMetric=600
EOF
cat > "$root/etc/systemd/system/wpa_supplicant@.service" <<'EOF'
[Unit]
Description=Wi-Fi connection on %I
After=systemd-udevd.service
Before=network.target
[Service]
Type=simple
ExecStart=/usr/sbin/wpa_supplicant -i%I -Dnl80211 -c/etc/wpa_supplicant/wpa_supplicant-%I.conf
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
cat > "$root/etc/ssh/sshd_config" <<'EOF'
Port 22
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
X11Forwarding no
Subsystem sftp internal-sftp
EOF
cat > "$root/etc/systemd/system/sshd.service" <<'EOF'
[Unit]
Description=OpenSSH server
After=network.target
[Service]
Type=simple
ExecStartPre=/usr/bin/ssh-keygen -A
ExecStartPre=/usr/sbin/sshd -t
ExecStart=/usr/sbin/sshd -D -e
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
cat > "$root/etc/systemd/system/pi-firstboot.service" <<'EOF'
[Unit]
Description=Pi LFS first-boot setup
ConditionPathExists=!/var/lib/pi-lfs/setup-complete
After=systemd-user-sessions.service systemd-networkd.service
Before=getty@tty1.service
[Service]
Type=oneshot
Environment=PATH=/usr/bin:/usr/sbin
UMask=0022
ExecStart=/usr/sbin/pi-setup
StandardInput=tty-force
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TimeoutStartSec=infinity
[Install]
WantedBy=multi-user.target
EOF
mkdir -p "$root/etc/systemd/system/getty@tty1.service.d"
cat > "$root/etc/systemd/system/getty@tty1.service.d/setup.conf" <<'EOF'
[Unit]
Wants=pi-firstboot.service
After=pi-firstboot.service
EOF
cat > "$root/etc/sudoers.d/wheel" <<'EOF'
%wheel ALL=(ALL:ALL) ALL
EOF
chmod 440 "$root/etc/sudoers.d/wheel"
printf '%s\n' 'LANG=C.UTF-8' > "$root/etc/locale.conf"
printf '%s\n' 'KEYMAP=us' > "$root/etc/vconsole.conf"
ln -sf ../usr/share/zoneinfo/Etc/UTC "$root/etc/localtime"
rm -f "$root/etc/resolv.conf"
ln -s ../run/systemd/resolve/stub-resolv.conf "$root/etc/resolv.conf"
cat > "$root/boot/firmware/SETUP.txt" <<'EOF'
Pi LFS USB edition — first boot

Connect a monitor to the Pi 4 primary micro-HDMI connector (nearest USB-C),
connect a USB keyboard, and boot this USB drive.
The console wizard creates an administrator account and scans nearby Wi-Fi.
Ethernet uses DHCP automatically. Wi-Fi country and password are entered on
this local console. Run sudo pi-setup to change Wi-Fi settings later.

SSH uses public keys only. Optionally copy your SSH public key(s) into a plain
text file named ssh-authorized-keys on this boot partition BEFORE first boot.
Never copy a private SSH key. The wizard can also accept a pasted public key.
No default password exists. The console password is chosen during setup.
The hostname is pi-lfs; find its IP in your router's DHCP client list or with
ip -br addr on the Pi. No .local/mDNS service is included.

Use Raspberry Pi Imager > Use custom to flash the .img file. Imager's usual
Raspberry Pi OS customization settings are not implemented by this image.
The Pi EEPROM boot order must include USB. Do not connect multiple copies of
this image simultaneously; they share the same disk PARTUUID.
EOF
chroot "$root" /usr/bin/env PATH=/usr/bin:/usr/sbin /bin/bash -c '
set -e
usermod -L root
systemctl enable dbus.socket systemd-networkd systemd-resolved systemd-timesyncd sshd pi-firstboot getty@tty1
systemctl disable systemd-networkd-wait-online.service || true
systemctl set-default multi-user.target
visudo -c
'
# These must be generated independently on each installed device.
rm -f "$root"/etc/ssh/ssh_host_* "$root/etc/machine-id" "$root/var/lib/dbus/machine-id" "$root/var/lib/systemd/random-seed"
touch "$root/etc/machine-id"
ln -sf /etc/machine-id "$root/var/lib/dbus/machine-id"
install -Dm644 /etc/ssl/certs/ca-certificates.crt "$root/etc/ssl/certs/ca-certificates.crt"
cp -a /usr/share/doc/ca-certificates/. "$root/usr/share/licenses/pi-lfs/ca-certificates/"

tar -xOf /build/pi/linux-ab437207.tar.gz linux-ab4372076bb840600e522ae776887ae2bc488fa6/LICENSES/preferred/GPL-2.0 > "$root/usr/share/licenses/pi-lfs/kernel-GPL-2.0"

# Preserve the upstream Shadow installation modes across build resumes.
chmod 4755 "$root"/usr/bin/{su,chage,chfn,chsh,expiry,gpasswd,newgrp,passwd,newgidmap,newuidmap}
