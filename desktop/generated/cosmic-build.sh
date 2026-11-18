#!/bin/bash
# Run INSIDE native aarch64 LFS chroot /build/desktop-lfs; configuration is separate.
set -Eeuo pipefail
export PATH=/usr/bin:/usr/sbin:/bin:/sbin
export CARGO_TARGET_DIR=/sources/cosmic-target CARGO_BUILD_JOBS=1 CARGO_INCREMENTAL=0
export CARGO_PROFILE_RELEASE_DEBUG=0 CARGO_PROFILE_RELEASE_LTO=false
export CARGO_PROFILE_RELEASE_INCREMENTAL=false MAKEFLAGS=-j1
umask 022
export LIBCLANG_PATH=/opt/buildtools/usr/lib/llvm-14/lib
export LD_LIBRARY_PATH=/opt/buildtools/usr/lib/aarch64-linux-gnu:/opt/buildtools/lib/aarch64-linux-gnu:/opt/buildtools/usr/lib/llvm-14/lib
export BINDGEN_EXTRA_CLANG_ARGS="-resource-dir=/opt/buildtools/usr/lib/llvm-14/lib/clang/14.0.6"
export ORCA=/usr/bin/orca
export POLKIT_AGENT_HELPER_1=/usr/lib/polkit-1/polkit-agent-helper-1
src=/sources/cosmic-epoch
pin=e98f8289a22f9e612feee7d4c6ba197782db154b
[[ $(uname -m) == aarch64 ]] || { echo 'Native aarch64 required' >&2; exit 1; }
[[ $(id -u) == 0 && -f /etc/lfs-release ]] || { echo 'Run inside LFS chroot as root' >&2; exit 1; }
[[ $(git -C "$src" rev-parse HEAD) == "$pin" ]]
if git -C "$src" submodule status --recursive | grep -Eq '^[-+U]'; then
    echo 'Submodule checkout missing or differs from release gitlinks' >&2; exit 1
fi
# Direct cargo binary ignores rustup toolchain override files. Never cargo update.
[[ $(command -v cargo) == /usr/bin/cargo && $(command -v rustc) == /usr/bin/rustc ]]
version=$(rustc --version | cut -d' ' -f2)
[[ $(printf '%s\n' 1.93.0 "$version" | sort -V | head -1) == 1.93.0 ]]
for command in just pkg-config cc cmake make git; do command -v "$command" >/dev/null; done
for module in wayland-client wayland-server xkbcommon libinput libudev libseat \
    egl gbm pixman-1 libdisplay-info fontconfig freetype2 dbus-1 libpipewire-0.3 \
    libpulse glib-2.0 gio-2.0 flatpak openssl; do
    pkg-config --exists "$module" || { echo "Missing native development library: $module" >&2; exit 1; }
done
python3 -c 'import ctypes,os;ctypes.CDLL(os.environ["LIBCLANG_PATH"]+"/libclang.so")' 
[[ -x $POLKIT_AGENT_HELPER_1 ]] || { echo 'Install polkit helper at configured path' >&2; exit 1; }
mkdir -p "$CARGO_TARGET_DIR"
components=(cosmic-applets cosmic-app-library cosmic-bg cosmic-comp cosmic-files cosmic-greeter \
 cosmic-idle pop-launcher cosmic-launcher cosmic-notifications cosmic-osd cosmic-osk cosmic-panel \
 cosmic-randr cosmic-screenshot cosmic-settings cosmic-settings-daemon cosmic-workspaces-epoch \
 cosmic-session cosmic-store cosmic-term xdg-desktop-portal-cosmic)
for component in "${components[@]}"; do
    (
        cd "$src/$component"
        if [[ -e /desktop-done/cosmic-$component ]]; then exit 0; fi
        echo "Building $component"
        test -s Cargo.lock
        args=(--locked --release -j1)
        case "$component" in
            cosmic-greeter) cargo build "${args[@]}" --workspace ;;
            cosmic-files)
                cargo build "${args[@]}"
                cargo build "${args[@]}" -p cosmic-files-applet
                cargo build "${args[@]}" -p cosmic-files-thumbnailer ;;
            pop-launcher) cargo build "${args[@]}" -p pop-launcher-bin ;;
            *) cargo build "${args[@]}" ;;
        esac
        echo "Installing $component"
        case "$component" in
            pop-launcher)
                # Upstream otherwise installs to root's ~/.local and ignores shared target dir.
                just rootdir=/ target-dir="$CARGO_TARGET_DIR/release" install ;;
            cosmic-workspaces-epoch) make -j1 prefix=/usr DEBUG=0 install ;;
            *) just prefix=/usr rootdir= install ;;
        esac
        touch /desktop-done/cosmic-$component
    )
done
(cd "$src/cosmic-icons" && just prefix=/usr rootdir= install)
# No aggregate `just install`: it has a build prerequisite for the entire epoch.
# Background assets do not need ImageMagick's resize/all target for installation.
(cd "$src/cosmic-wallpapers" && make -j1 prefix=/usr install)
if command -v gtk-update-icon-cache >/dev/null; then gtk-update-icon-cache -f -t /usr/share/icons/hicolor; fi
if command -v update-desktop-database >/dev/null; then update-desktop-database /usr/share/applications; fi
if command -v update-mime-database >/dev/null; then update-mime-database /usr/share/mime; fi
ldconfig
