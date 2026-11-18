#!/bin/bash
# Inside the image build root; install payloads now, never at first login.
set -euo pipefail
export PATH=/usr/bin:/usr/sbin
for remote in flathub cosmic; do
    flatpak remote-add --system --if-not-exists "$remote" "/usr/share/bravion/flatpak/$remote.flatpakrepo"
done
flatpak install --system --noninteractive --assumeyes flathub com.brave.Browser
flatpak update --system --appstream
location=$(flatpak info --system --show-location com.brave.Browser)
# A successful metadata deployment alone is insufficient: require the browser payload.
test -x "$location/files/brave/brave"
flatpak info --system --show-runtime com.brave.Browser | grep -q '^org.freedesktop.Platform/'
install -d /usr/share/icons /usr/share/bravion
cp -a "$location/export/share/icons/." /usr/share/icons/
{
    flatpak info --system com.brave.Browser
    flatpak list --system --columns=ref,active,origin
    flatpak remotes --system --columns=name,url,options
} > /usr/share/bravion/flatpak-build.txt
# Retire the native distribution without leaving a duplicate desktop entry.
rm -rf /opt/brave.com
rm -f /usr/share/applications/brave-browser.desktop
