# Validation record — automatic image pipeline

The automatic pipeline is under clean-build validation. This document separates verified components from an uncompleted full build.

## Checks executed on 2026-11-18

- Repository checks: 39 Python tests, two Brave launcher tests, source/recipe syntax and manifest checks passed.
- Rust Store: 16 tests passed inside the native ARM64 LFS environment.
- COSMIC pointer helper: five Rust regression tests passed.
- Builder Dockerfile: built successfully for ARM64.
- Image packaging: the current generic packager rebuilt a clean 0.11.1 Raspberry Pi root; FAT and ext4 checks passed, and exported bytes matched their checksum.
- Compression and artifact verification: the newly repackaged test image passed XZ integrity, SHA-256, and a disposable QEMU boot probe through kernel, systemd, and the first-boot service. Its compressed size was 1,029,647,064 bytes; this is a validation artifact, not a new release.

The packaging test reused a prepared root. It does **not** prove the new source compilation stages. Boot probing starts the first-boot service; it does **not** verify graphical login, physical Raspberry Pi hardware, or application installation.

- Parallels packaging: generated a fresh sanitized PVM ZIP from the existing clean ARM64 release. Raw/HDS comparison, ZIP CRC, SHA-256, and the disposable direct-kernel boot probe passed. Compressed size: 1,634,195,588 bytes. Importing this newly assembled bundle in Parallels remains a separate check.

## Faults found and corrected

1. Container restarts discarded virtual filesystem mounts needed by guest build tools. Guest execution now restores them; a regression test failed before the correction and passed afterwards.
2. The inherited source list included five unused SysV-era archives absent from the systemd checksum manifest. One URL failed and aborted downloads. The list now matches the 92 verified systemd sources exactly, covered by a regression test.

3. Build DNS setup now preserves the runtime systemd-resolved symlink, using the private `/run` mount for build-only DNS. A regression test failed before the correction and passed afterwards.
4. Builder images now contain a source snapshot instead of mounting the editable checkout, preventing host edits from silently changing inputs during a build.

5. The empty ARM64 build reached chapter 8, then Expect failed because its 2003 GNU configuration scripts do not recognize AArch64. Expect now uses `config.guess` and `config.sub` from the pinned Binutils archive. The corrected package compiled and installed successfully in that LFS root; a new clean pipeline run was started with the correction.
6. The older AMD64 controller failed to resolve `chroot` through its process PATH. It now invokes `/usr/sbin/chroot`; base-system compilation resumed.

7. Auditing the prepared root revealed nine Python build dependencies absent from the LFS base. Their exact source versions and SHA-256 digests are now pinned, and all nine compiled/installed from source successfully in the base LFS environment, with import checks.
8. The AMD64 libdrm recipe now enables Intel/AMD libraries and builds libpciaccess first. Regression tests verify the flags and dependency order; actual PC GPU operation is not yet tested.
9. Checkpoint input fingerprints allow corrections to unstarted stages while rejecting changes to started/completed stages. Tests cover both cases and shared-helper invalidation. Existing validation state was initialized only after verifying that its original source snapshot matched its recorded hash; the accepted changes affect future runtimes (and, on the older ARM snapshot, future desktop package recipes).

10. Review found missing launcher/builder fingerprint coverage and a mode-change bypass. New regressions failed before the fixes; fingerprints now include the launcher, builder and unclassified inputs, and are checked even when the content digest is unchanged.
11. Review also found that a package failure left a blocking partial image. An injected mkfs failure reproduced this with the old script. Unique attempt staging and ownership receipts now allow retry and recovery of a missing checksum; the same fault test passed with the correction. The reproducible fixture is `tests/integration/package-retry.sh`, intended only for a disposable privileged container.

12. The ARM LFS order omitted libpipeline, causing man-db configuration to fail. Its recipe and verified source already existed. Added it immediately before the failed man-db, preserving the completed prefix. Granular LFS input plans now reject changes to compiled/started recipes and builder controls, while allowing this pending dependency. Six resume tests and real recipe fingerprint tests passed; the resumed pipeline compiled libpipeline and man-db, then completed the LFS stage. Old-plan metadata was derived only from the verified original source snapshot.

## Still pending

- A complete successful run from empty storage through the final artifact check.
- Full AMD64 system compilation and boot.
- Fresh-account graphical and physical hardware tests of newly generated images.

A build only reports `IMAGE_COMPLETE` after every stage, compression, checksum verification, and boot probe succeeds. Per-target artifact reports explicitly record graphical and physical tests as false until independently performed.
