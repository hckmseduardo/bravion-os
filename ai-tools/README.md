# Bravion Store 0.11

Rust/GTK3 app store for the Bravion LFS desktop. The original generated icon
is used in the window, header and desktop/first-login launchers. Official
publisher icons remain on application cards. Installs remain per user,
without sudo. The existing twelve Rust tests pass.

`../branding/install-branding.py` installs the compiled binary, launchers,
icons, default COSMIC wallpaper and distribution metadata into a mounted LFS
root. It refuses `/` and roots without `/etc/lfs-release`.

Build in the prepared LFS ARM64 environment with GTK3 development files:

    cargo test
    cargo build --release

At this release, desktop download feeds are ARM64-specific. The AMD64 port
must add verified architecture selection before it can be released.

Native desktop previews remain experimental on LFS. Claude Cowork
virtualization is not configured. Authentication happens with each provider.
No credentials are included in the release images.
