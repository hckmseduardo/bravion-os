#!/bin/sh
# Parallels' virtual GPU cannot import Brave's Wayland DMA-BUF buffers.
if [ -f /etc/pi-lfs-vm ]; then
    set -- --disable-gpu "$@"
fi
exec /usr/bin/flatpak run --system com.brave.Browser --ozone-platform=wayland "$@"
