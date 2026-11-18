# Third-party components and notices

Bravion is a distribution of components with separate licenses. Full GPL-2.0 and GPL-3.0 texts are included under `licenses/` and copied into generated images. The repository's MIT license is not a license for every component in the generated operating system.

| Material | Origin and applicable terms |
| --- | --- |
| LFS-derived package commands | Linux From Scratch 13.0-systemd, Copyright © 1999–2026 Gerard Beekmans. The MIT notice is preserved in `research/LFS-MIT-license.html`. |
| BLFS package recipes | Derived from Beyond Linux From Scratch guidance and the commands used in Bravion's build. Downloaded upstream source retains its own notices and licenses. |
| COSMIC modifications under `patches/cosmic` | Derived compositor patches retain GPL-3.0-only, matching COSMIC compositor source. These terms also apply to the helper integrated into that patch. |
| Linux kernel patch | A modification of Linux kernel code; the kernel's GPL-2.0-only terms apply. The pinned source and its COPYING/LICENSES files are downloaded during the build. |
| Kernel, firmware, desktop, libraries, build tools | Downloaded from the upstream projects identified by manifests and recipes. Their own license files govern use and redistribution. Firmware can have additional distribution conditions. |
| Rust, Node.js, Brave | The builder installs pinned upstream binary distributions for these components; it does not compile every runtime or browser from source. Their respective licenses and notices apply. |
| Vendor app icons in `ai-tools/assets` | Product-identification assets for the corresponding publishers. Names, logos, and trademarks belong to their owners and are excluded from Bravion's MIT grant. Inclusion does not imply endorsement or ownership. |
| Optional Store downloads | Obtained from publishers during installation; accounts, authentication, subscriptions, and publisher terms remain separate. |
| Parallels Tools | Proprietary input supplied from the builder operator's installation. The ISO and installer are not committed to this source repository. Generating a local VM does not grant permission to redistribute proprietary components. |

The Bravion logo and wallpaper are original AI-assisted artwork created for this project; they contain no copied fictional-character artwork. The Bravion name and identity do not imply a relationship with other product owners.

A source repository and a binary operating-system release have different redistribution obligations. Keep upstream notices and corresponding source requirements with any binary release. This repository currently hosts source tooling, not public prebuilt image assets.
