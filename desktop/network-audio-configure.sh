#!/bin/bash
set -euo pipefail
umask 022
r=/build/desktop-lfs
for marker in networkmanager pipewire wireplumber wpa-dbus; do test -f "$r/desktop-done/$marker"; done
install -Dm755 /workspace/build/pi_setup.py "$r/usr/libexec/pi-lfs/pi_setup_base.py"
install -Dm755 /workspace/desktop/pi_desktop_setup.py "$r/usr/sbin/pi-setup"
install -Dm644 /workspace/desktop/pi-wifi-country.service "$r/etc/systemd/system/pi-wifi-country.service"
test -x "$r/usr/sbin/iw"
install -dm755 "$r/etc/NetworkManager/conf.d"
cat > "$r/etc/NetworkManager/conf.d/10-pi-desktop.conf" <<'CONF'
[main]
plugins=keyfile
auth-polkit=true
dns=systemd-resolved
[device]
wifi.backend=wpa_supplicant
CONF
# Fresh desktop image: no prior user connection data is retained from base image.
find "$r/etc/systemd/network" -maxdepth 1 -type f -name '*.network' -delete
find "$r/etc/wpa_supplicant" -maxdepth 1 -type f -name 'wpa_supplicant-*.conf' -delete
systemctl --root="$r" disable systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service systemd-networkd-varlink.socket systemd-networkd-resolve-hook.socket
# Disable per-interface and standalone boot starts, preserve D-Bus activation.
find "$r/etc/systemd/system" -type l -name 'wpa_supplicant@*.service' -delete
systemctl --root="$r" disable wpa_supplicant.service
systemctl --root="$r" enable NetworkManager.service systemd-resolved.service
systemctl --root="$r" disable NetworkManager-wait-online.service
install -dm755 "$r/run/systemd/resolve"
# Build-only runtime DNS file in private tmpfs; resolved replaces it on real boot.
cp /etc/resolv.conf "$r/run/systemd/resolve/stub-resolv.conf"
ln -sfn /run/systemd/resolve/stub-resolv.conf "$r/etc/resolv.conf"
mkdir -p "$r/etc/systemd/system/pi-firstboot.service.d"
cat > "$r/etc/systemd/system/pi-firstboot.service.d/networkmanager.conf" <<'CONF'
[Unit]
After=
After=systemd-user-sessions.service NetworkManager.service
Wants=NetworkManager.service
Before=cosmic-greeter.service
CONF
systemctl --root="$r" --global enable pipewire.socket pipewire-pulse.socket wireplumber.service
# Client-only PulseAudio is installed; never autospawn an audio daemon.
rm -f "$r/etc/xdg/autostart/pulseaudio.desktop" "$r/etc/xdg/Xwayland-session.d/00-pulseaudio-x11"
if test -f "$r/etc/pulse/client.conf"; then
 sed -i '/^[[:space:];#]*autospawn[[:space:]]*=/d' "$r/etc/pulse/client.conf"
 printf '\nautospawn = no\n' >> "$r/etc/pulse/client.conf"
fi
chroot "$r" /usr/bin/env -i PATH=/usr/bin:/usr/sbin HOME=/root /bin/bash <<'CHECK'
set -euo pipefail
NetworkManager --version
nmcli --version
for binary in /usr/sbin/NetworkManager /usr/bin/nmcli /usr/bin/pipewire /usr/bin/pipewire-pulse /usr/bin/wireplumber /usr/bin/wpctl /usr/sbin/wpa_supplicant; do
 ldd "$binary"
done > /desktop-logs/network-audio-links.txt
! grep -q 'not found' /desktop-logs/network-audio-links.txt
systemd-analyze verify --man=no /usr/lib/systemd/system/NetworkManager.service /usr/lib/systemd/system/systemd-resolved.service /etc/systemd/system/wpa_supplicant.service /etc/systemd/system/pi-firstboot.service /etc/systemd/system/pi-wifi-country.service
python3 -m py_compile /usr/sbin/pi-setup /usr/libexec/pi-lfs/pi_setup_base.py
CHECK
for unit in NetworkManager.service systemd-resolved.service; do systemctl --root="$r" is-enabled "$unit"; done
for unit in systemd-networkd.service systemd-networkd.socket systemd-networkd-varlink.socket systemd-networkd-resolve-hook.socket; do
 if systemctl --root="$r" is-enabled "$unit" 2>/dev/null; then echo "Unexpected enabled networkd unit: $unit"; exit 1; fi
done
test "$(readlink "$r/etc/resolv.conf")" = /run/systemd/resolve/stub-resolv.conf
for unit in pipewire.socket pipewire-pulse.socket wireplumber.service; do systemctl --root="$r" --global is-enabled "$unit"; done
touch "$r/desktop-done/network-audio-integration"
echo 'NetworkManager, resolved, firstboot and user PipeWire configured; no daemons started'
