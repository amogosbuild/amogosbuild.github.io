# AmogOS 2 Pro Installer

Flutter 3.47.6 desktop installer for the Debian 13 Chocolatier ISO.

Includes light and pitch-black themes, smart/erase/manual storage setup, account
and locale configuration, hardware recommendations, optional network upgrades,
four Amogus games, and the AmogOS Installer Music playlist.

Boot setup offers GRUB, UEFI systemd-boot, or an existing bootloader, with
automatic placement or an explicitly reviewed boot disk/partition. The Plymouth
theme under boot/plymouth/amogos2pro displays shimmering AmogOS 2 Pro text and a
sliding red light on a black background during live and installed boot.

The Windows build is an explicitly labelled design preview with sample hardware.
Disk installation is enabled only in the Linux live image after a reviewed and
confirmed plan. The backend refuses disk installation on the VPS.

Source organization and storage behavior are documented in docs/architecture.md.

## Windows preview

    & "$env:USERPROFILE\Downloads\flutter_windows_3.47.6-stable\flutter\bin\flutter.bat" run -d windows

Release executable:

    build/windows/x64/runner/Release/amogos_installer.exe

## VPS build

Source mirror: /srv/chocolatier/apps/installer

Application ID: amogos.installer. Launch with amogos-installer from a terminal.

    /srv/chocolatier/scripts/build-installer

Package: /srv/chocolatier/apps/installer/dist/amogos-installer_0.1.3-1_amd64.deb

The SDK stays in the build environment. Only the compiled applications and their
runtime dependencies are installed in the ISO.

After installing the Debian package in the editable rootfs, refresh the live
boot theme and initramfs before repacking another development checkpoint:

    bash /srv/chocolatier/apps/installer/scripts/configure-live-boot.sh
    /srv/chocolatier/scripts/repack-installer-checkpoint New-Development-Checkpoint.iso

## Checks

    flutter analyze
    flutter test
    python -m unittest discover -s backend/tests -v
    dart run tool/check_music.dart
    python scripts/source_comments.py --normalize

Rendered previews are generated under build/previews. Privileged development
tests use verified disposable loop images or the dedicated QEMU test disk.
Their logs are kept under /srv/chocolatier/logs.

## Assets

The supplied character is named Amogus in the installer and games:
https://static.wikia.nocookie.net/amogus/images/c/cb/Susremaster.png/revision/latest?cb=20210806124552

Music resolution and native playback were adapted from the user's
Documents/amogos-music project. The exact featured Installer Music playlist is
used. Manrope and Flutter runner license files are retained under third_party/.


Compact windows use a horizontal step indicator, stacked form fields and footer controls, and scrollable storage and arcade content. Music keeps playback controls in a Player tab on smaller screens. All steps are tested at 360×640, 640×480, 800×600 and 1024×600 with 130% text. Native windows fit the monitor work area.

Games stay on the selected game after a loss with a Try again action; switching games is manual. The arcade renders at up to 30 fps using fixed simulation steps, redraws only its canvas, and stops ticking before play, after a loss, while paused, during music dialogs, and when the application is inactive. Hidden Amogus uses a one-second countdown timer and redraws only when its scene changes. Sprite paints are reused and enemies/effects are bounded.

The Debian packaging revision 0.1.2-1 gives the installer launcher an explicit PNG icon path in /usr/share/pixmaps, retaining themed app ID icons as well. The supplied character asset is WebP data despite its .png extension. A separate 256×256 RGBA PNG is used for desktop icons, so Qt does not require a WebP decoder to show the installer. The original Flutter character asset is preserved.

Version 0.1.3 checks online repositories before partitioning, performs a full
system upgrade, and verifies that no pending or unconfigured packages remain.
The result is saved on the installed system in
/var/log/amogos-installer/package-updates.json. Required AmogOS and desktop
packages cannot be removed by the upgrade. Target kernels installed by updates
are preserved and receive a regenerated initramfs with the Amogus boot theme.

The ISO's system preparation provides broad Wi-Fi firmware, Intel/AMD Mesa and
Nouveau, Steam and matching 32-bit graphics libraries. A verified offline archive
contains NVIDIA and Broadcom STA packages and their dependencies. Hardware
detection chooses supported proprietary drivers for the target when enabled,
including without an internet connection. See ../system/README.md for staging
scripts, the driver manifest and isolated installation checks.
