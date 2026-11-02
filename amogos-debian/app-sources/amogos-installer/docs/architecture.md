# Installer architecture

The Flutter frontend runs as the live desktop user. Disk operations run in a
separate root-owned Python helper authorized through polkit. Passwords travel
over standard input and are not placed in arguments, saved plans, or logs.
Installation is enabled only in the live overlay with its live squashfs present.

## Source folders

- lib/app/: application ownership and light/pitch-black Material 3 themes.
- lib/core/: inventory models, wizard controller, and helper transport.
- lib/features/setup/: wizard pages, persistent shell, and progress pill.
- lib/features/games/: game engines, bounded canvas rendering, and manual retries.
- lib/features/music/: player, dialog, and adapted AmogOS Music code.
- backend/amogos_install/: discovery, planning, drivers, and installation.
- backend/cli.py: fixed-action privileged dispatcher.
- packaging/: desktop integration, polkit action, and Debian metadata.
- boot/plymouth/: the AmogOS 2 Pro scripted splash and its image assets.
- scripts/: builds and disposable filesystem/VM integration tests.
- test/ and backend/tests/: Flutter and storage regression tests.

## Storage workflow

1. Discover physical disks, operating systems, free extents, and shrink limits.
2. Exclude installation media, mounted volumes, and active device mappings.
3. Build a plan without disk writes. Save a random token in a root-only directory,
   bind it to the authorizing UID, and record the current layout fingerprint.
4. Show each change and preserved OS in the review screen.
5. Require the disk name and acknowledgement in the final confirmation.
6. Revalidate the live environment, account, token, layout, and resize eligibility.
7. Shrink a supported filesystem before reducing its partition boundary.
8. Format only the reviewed root and newly created EFI partitions.
9. Extract the live system, configure the account, and apply the chosen boot setup.

Smart mode prefers unallocated space. It can shrink clean, offline NTFS or ext4
with conservative margins. Dirty/hibernated NTFS, BitLocker, LUKS, XFS, Btrfs,
LVM, RAID, and unsupported MBR arrangements are not automatically shrunk.
Suitable unallocated space can still be used alongside those systems.

Manual mode assigns an existing partition as formatted root or allocates a new
root inside a chosen free extent. It can preserve an existing ESP. It does not
provide every operation found in a general-purpose partition editor.

Default GRUB erase mode creates GPT, BIOS boot, EFI, and ext4 root partitions. Alongside mode
preserves existing EFI files and uses the current firmware mode. GRUB detects
other operating systems through os-prober and retains a Windows EFI chainloader.
Secure Boot signing is outside this checkpoint.

## Boot setup and Plymouth

GRUB supports legacy BIOS and UEFI. systemd-boot is offered only under UEFI;
it stores kernels and initramfs on the chosen ESP and has persistent kernel and
initramfs hooks to refresh its Boot Loader Specification entries. An existing
ESP needs at least 512 MiB total and 256 MiB free; a new ESP uses 1 GiB.

Custom placement can use a different disk's existing EFI or reserved BIOS boot
partition. Its layout fingerprint is revalidated and both disk names must be
typed at confirmation. The other disk is not automatically repartitioned and
its existing EFI files are preserved. BIOS GRUB targets the disk boot sector
with a reserved embedding area; ordinary filesystem partition boot sectors are
not offered. Skipping the loader requires manual existing-loader configuration.

The Plymouth script draws the AmogOS 2 Pro name with a moving highlight and a
sliding gradient light. It runs without input while boot continues. Password,
question, and status callbacks remain available. The default theme is selected
before the installer regenerates initramfs, and both GRUB and systemd-boot pass
quiet splash on normal installed boot. The live initrd receives the same theme.

## Hardware and updates

PCI/USB identities, module aliases, and Debian nvidia-detect provide hardware
recommendations. Common Intel, Realtek, Atheros/Qualcomm, Broadcom, MediaTek, AMD,
and Nouveau firmware are bundled in the ISO workspace. Supported proprietary
NVIDIA drivers are selected by nvidia-detect and downloaded when online.
The installer reports unavailable packages rather than claiming they installed.
Full package upgrades remain optional.

## Entertainment lifecycle

Music is independent of wizard navigation and installation progress. The default
playlist is PLtDV_xTX8E0uQaRGRL4B3Sp1GCKNCHH3J, the AmogOS Installer Music playlist
from the user's Music project. Direct InnerTube audio, HLS, and a maintained
library fallback resolve playback. Network errors do not interrupt installation.

The arcade appears while installation is running. A loss keeps the selected game
on screen until Try again or another game is chosen. Enter also resets the
current game after a loss. Flappy accepts Space; Crossy accepts arrow/WASD keys
and on-screen buttons. Opening the soundtrack dialog pauses gameplay.

Animated games repaint only their isolated canvas at up to 30 fps, using fixed
1/60-second simulation steps and bounded catch-up after a stall. Their controls
rebuild only when scores or state change. The clock stops before play, after
loss, when paused, and while the application is inactive. Hidden Amogus uses a
one-second countdown timer and redraws its static scene only after interaction.
Sprite paints and tint filters are reused; enemy and particle counts are bounded.

Compact windows use horizontal steps, a stacked footer and form fields, and
scrolling content. Music exposes Player, Up next and Find music tabs on smaller
screens, keeping playback controls reachable.

Each maintained source file has one concise comment. Flutter regenerates native
plugin registration files; scripts/source_comments.py --normalize restores the
convention after building.
