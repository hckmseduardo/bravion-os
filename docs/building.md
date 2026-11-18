# Build Bravion automatically

The build entry point is `./bravion build`. Do not run individual package recipes manually.

## Prerequisites

- Docker with privileged Linux containers and support for the target architecture.
- Python 3 on the host to run the CLI.
- A dedicated writable storage directory outside the checkout, with at least 80 GiB free space. An SSD is recommended. Do not disconnect an external build disk while a build runs.
- Preferably 8–16 GiB RAM available to Docker. Start with `--jobs 1` on smaller machines.
- Internet access to upstream archives, Git repositories, and Rust dependencies.

Native ARM64 and AMD64 workers avoid emulation overhead. Docker Desktop or another compatible Linux VM is required on macOS. The image builder is privileged because it mounts its own regular disk-image files. It never chooses or formats a physical drive.

## Generate an image

```sh
git clone https://github.com/hckmseduardo/bravion-os.git
cd bravion-os
./bravion check
./bravion build --target pi4-arm64 --storage /absolute/path/bravion-pi4 --jobs 1
```

Targets:

| Target | Container architecture | Output |
| --- | --- | --- |
| `pi4-arm64` | `linux/arm64` | Pi 4 USB `.img.xz` |
| `parallels-arm64` | `linux/arm64` | Apple Silicon `.pvm.zip` |
| `amd64` | `linux/amd64` | Intel/AMD 64-bit EFI `.img.xz` |

The Parallels build requires the official ARM64 Tools ISO. On a Mac with Parallels installed, the CLI discovers it automatically. Otherwise pass `--tools-iso /absolute/path/prl-tools-lin-arm.iso`. Obtain it through your own licensed installation. The source repository does not contain it.

## Automatic stages

The CLI builds a Docker image containing a fixed copy of the source, then runs the complete pipeline:

1. Download and verify pinned sources.
2. Build the LFS toolchain and base system.
3. Build networking, SSH, kernel, drivers, and firmware.
4. Build desktop libraries, Rust/Node runtimes, COSMIC, and the Rust Store.
5. Apply branding, first-boot configuration, and display corrections.
6. Package a disk sized from installed contents; check both filesystems.
7. Compress or convert to a Parallels VM bundle.
8. Verify checksums and archive integrity; boot a disposable VM snapshot until the first-boot service starts.

No intermediate hand-built root filesystem, personal VM, or manually installed desktop is required by the pipeline. Current clean-build validation status is recorded in [validation.md](validation.md); the complete new pipeline has not yet finished that validation.

## Follow progress and resume

```sh
./bravion status --storage /absolute/path/bravion-pi4
```

The CLI streams stage changes. Detailed package logs live inside `build.ext4`; the target state is mirrored to `<storage>/status/status.json`. Final images, checksums, validation JSON, and boot logs are placed in `<storage>/outputs`.

Repeat the same build command after a failure. Successful stages have checkpoints. An architecture change or a source change affecting a stage already started requires a new storage directory. Corrections limited to future, unstarted stages can resume automatically: stage input fingerprints verify that all previous inputs are identical, and the transition is recorded. Within an incomplete LFS stage, a pending package can also be added or corrected only when the completed ordered prefix, every started recipe, and the builder/executor inputs remain unchanged. Completed LFS stages cannot be reopened this way. Download mirror URLs are transport metadata: a mirror-only change can resume when the mandatory archive SHA-256 and every material package input stay identical. Do not edit state files to bypass these checks.

Compilation is a long-running task; an ARM Mac emulating AMD64 can take substantially longer. There is no promise that a full desktop build fits a free hosted CI runner's disk, RAM, or job duration.

## What completion means

`IMAGE_COMPLETE` is printed only after the final artifact checks pass. A boot probe proves kernel/systemd startup and initiation of the setup service, not a complete graphical login or physical-device compatibility. Artifact reports keep those independent tests explicitly separate. See [installation.md](installation.md) for testing the result.

## GitHub Actions

`Source checks` runs on pushes and pull requests using a hosted Ubuntu worker. `Generate image` provides a workflow-dispatch entry point for a trusted self-hosted worker; once started, it runs the same automatic CLI through final image validation.

Register native Docker-capable workers with the custom labels `bravion-arm64` or `bravion-amd64`, and make the selected storage parent writable by the worker account. This is a one-time infrastructure prerequisite, not a manual operating-system build stage. Parallels builds also need the official local ISO at the automatic Mac discovery path. The workflow retains images on the worker and does not upload proprietary components or publish a release automatically. A hosted runner is not promised to have sufficient resources for the complete build.
