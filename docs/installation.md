# Install and test an image

Use an image built for your platform. ARM64 Pi boot firmware, ARM64 Parallels EFI, and AMD64 PC EFI are different targets.

## Raspberry Pi 4

1. Verify the downloaded archive using its SHA-256 sidecar.
2. Open Raspberry Pi Imager, choose **Use custom**, and select the `.img.xz` file.
3. Select the USB drive and write the image. This erases that selected drive.
4. Boot a Pi 4 with USB boot enabled in its EEPROM, a keyboard, display, and suitable power supply.
5. Create your own account and password. Choose your Wi-Fi country and network, or use Ethernet.

The initial setup and desktop require physical testing on your hardware. Generated content size and USB capacity differ; root expansion runs at startup when the supported partition layout allows it.

## Apple Silicon Parallels

Extract the `.pvm.zip`, then open the `.pvm` in Parallels. Create your account on first boot; no default password is supplied.

The image includes the corrected COSMIC absolute-pointer mapping for an extended desktop. The vendor graphical Tools client is disabled because its desktop-specific dynamic-resolution integration caused incorrect display and mouse behavior with COSMIC. The Tools daemon is separate. Configure extra virtual displays while the VM is shut down, then arrange outputs in COSMIC Settings.

## AMD64

This edition is under construction and has no verified bootable release yet. The pipeline targets EFI PCs and EFI VMs with Intel or AMD 64-bit processors. It does not currently claim Secure Boot support or universal hardware coverage.

## Check a new image

Confirm first-boot account setup, Ethernet/Wi-Fi and DNS, graphical login, keyboard/mouse, extended displays where supported, browser startup, audio input/output, and tool installation from Bravion Store. Report the exact version, architecture, hardware/hypervisor, error, and reproduction steps. Remove credentials and personal data from logs.
