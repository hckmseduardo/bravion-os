# Contributing to Bravion

Bravion is experimental. Contributions that make a clean automated build reliable and a fresh installation usable are especially valuable.

1. Open an issue describing a concrete problem or intended behavior.
2. Make a focused change, preserving the architecture separation between Pi ARM64, Parallels ARM64, and PC AMD64.
3. Run `./bravion check`. For Store changes, also run `cargo test --locked --manifest-path ai-tools/Cargo.toml` on Linux with GTK 3 development libraries.
4. Test the affected stage or image and report exactly what was exercised. A successful unit test is not a successful boot or graphical login.
5. Submit a pull request describing the problem, behavior after the change, and validation evidence.

Keep downloads pinned and checksummed. Do not silently update a source pin or Cargo lockfile while fixing another issue. Architecture-specific app feeds must select the correct CPU before choosing a release.

Never commit passwords, API tokens, account databases, host keys, Wi-Fi profiles, personal VM bundles, vendor ISOs/installers, or large generated images. Use synthetic data in tests. Preserve third-party notices and include the relevant license when adding assets or dependencies.

Bug reports should include version, target, hardware or hypervisor, reproduction steps, expected/observed results, and relevant logs with personal data removed. For build failures, include the failing stage and package log, not only the final Python wrapper exception.
