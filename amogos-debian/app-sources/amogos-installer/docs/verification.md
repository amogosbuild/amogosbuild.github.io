# Development verification — 31 October 2026

AmogOS 2 Pro remains a development checkpoint for further ISO changes.

## Passed

- Windows and Debian 13 Linux release builds with Flutter 3.47.6 / Dart 3.13.5.
- Flutter static analysis: no issues.
- Eight Flutter tests: game behavior, light/pitch-black themes, responsive layouts,
  explicit confirmation, and custom boot placement with both disk names.
- Eighteen backend tests: storage boundaries, preserved ESPs, changed layouts,
  firmware compatibility, boot destinations, and kernel/initramfs synchronization.
- Exactly one comment in every maintained source file (96 files).
- Real NTFS and ext4 shrink tests on verified disposable loop-backed images:
  preserved file bytes, filesystem UUIDs, partition starts/GUIDs, and EFI contents.
- Live InnerTube check: the exact Installer Music playlist returned ten tracks
  and a playable, range-validated audio stream.
- The privileged backend refused non-live disk installation on a non-live build host.
- Live Plymouth rendered the AmogOS 2 Pro title, moving text highlight, and
  sliding gradient light, and continued into userspace without input.
- A complete installation onto a disposable 32 GiB QEMU root disk using an
  existing EFI partition and reserved BIOS boot area on a second 2 GiB disk.
- Installed account, fstab, kernel, initramfs, release name, theme, and GRUB files
  checked; the other disk's pre-existing EFI fallback file remained byte-identical.
- That installed system booted through external-drive GRUB under both BIOS and
  UEFI with the live ISO disconnected. Screenshots show Plymouth on both paths.
- systemd-boot installation on the external ESP and its actual post-initramfs
  synchronization hook passed; the copied initramfs was compared byte for byte.
- The installed system then booted through systemd-boot under UEFI without the
  live ISO, with Plymouth verified in the captured boot frames.
- The final checkpoint006 ISO passed SHA-256 and read-only embedded-file checks
  for the compiled app, backend, theme assets, live initramfs, and desktop launchers.
- The exact checkpoint006 image booted as UEFI USB media through GRUB, the kernel,
  live userspace, and SDDM startup.

The full installation test used checkpoint005's live payload and the current
backend. Checkpoint006 adds explicit legacy-boot destination wording to the
reviewed plan and consistent release branding. Its exact finished image received
separate embedded-file verification and a UEFI USB boot test. Earlier desktop
startup and filesystem-resize evidence is retained alongside the new VM logs.

Physical Windows/Linux dual-boot machines and NVIDIA hardware have not yet been
tested. Automatic shrinking is limited to eligible NTFS/ext4; encrypted and
unsupported layouts need space prepared separately.

## Build evidence

- $AMOGOS_BUILD_DIR/logs/test-pro-boot.log
- $AMOGOS_BUILD_DIR/logs/latest-pro-boot.txt
- $AMOGOS_BUILD_DIR/logs/pro-boot-20261031T171359Z/
- $AMOGOS_BUILD_DIR/logs/checkpoint006-boot-result.json
- $AMOGOS_BUILD_DIR/logs/AmogOS-2-Pro-Installer-checkpoint006-verification.json
- $AMOGOS_BUILD_DIR/logs/pro-checkpoint006-build.log
- $AMOGOS_BUILD_DIR/logs/test-filesystems.log
- $AMOGOS_BUILD_DIR/logs/installer-comment-audit.log
- $AMOGOS_BUILD_DIR/logs/installer-source-sha256.json

Current ISO:

    $AMOGOS_BUILD_DIR/output/AmogOS-2-Pro-Installer-checkpoint006.iso

Rendered interface and real VM boot captures are under build/previews in the
Windows workspace. The original ISO and earlier checkpoints are preserved.


## Staged 0.1.2 checks

Windows and Debian 13 Linux release builds passed static analysis. All 18 Flutter
tests and 18 backend tests passed. New arcade tests verify manual retry, no
switch after loss, the 30 fps paint bound, fixed simulation time, bounded stall
catch-up, unchanged controls during animation, and paused countdown/input.
Responsive tests exercise all seven steps and compact music tabs at 360×640,
640×480, 800×600 and 1024×600 with 130% text in both themes. The native Linux
window fits within 608×416 on a 640×480 display and retains amogos.installer as
WM_CLASS. The DEB is staged in the editable rootfs. No ISO was rebuilt.


## Desktop icon packaging revision 0.1.2-1

The desktop icon source was WebP data under a PNG filename. A separate genuine
256×256 RGBA PNG is now packaged under pixmaps and both themed icon names, and
the desktop launcher uses its explicit pixmaps path. The Flutter character
asset remains unchanged. Desktop-file validation and a fresh native Plasma 6
session confirmed that the corrected desktop icon renders. The package is
staged in the editable rootfs; the ISO has not been rebuilt.
