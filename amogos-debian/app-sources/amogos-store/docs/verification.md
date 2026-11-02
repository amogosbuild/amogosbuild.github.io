# Development verification

This is a development checkpoint for continued AmogOS 2 Pro work.

## Completed checks

- Eight Flutter tests passed, covering rendered black/light themes, responsive
  layouts, the moving navigation dot and bold label, one/two/three-format source
  choices, serial queue execution, queue revalidation, special shoppers, and
  the missing-Flatpak installation prompt with its main app action disabled.
- Flutter analysis passed with no issues.
- Nine backend boundary tests passed, checking package IDs, download architecture,
  private-address rejection, root AppImage refusal, manifest confinement,
  owner-bound single-use expiring review tokens, process timeouts, progress,
  and the missing-Flatpak requirement.
- Real live catalogs returned APT, Flathub, and AppImageHub entries.
- Krita resolved available entries in all three formats; APT repository filtering
  returned only the selected repository.
- Real APT installation/removal of hello passed in the isolated Debian build
  chroot, including rejection of a consumed transaction token.
- Real system Flatpak installation/removal of GNOME Calculator passed there.
- A real AppImageHub download passed ELF/architecture and checksum validation,
  user desktop integration, receipt creation, and removal without root execution.
- Windows and Debian Linux release builds passed. The latest Windows executable
  is also copied to the maintained project's build/windows/x64/runner/Release.
- The native Linux store started as the regular storetest account under Xvfb;
  its real catalog and a naturally selected semi-rare shopper were captured.
- Checkpoint007 passed SHA-256 and read-only checks against the compiled store,
  backend, fixed helper, desktop launcher, and all seven original character PNGs.
- The exact checkpoint007 ISO booted as UEFI USB media through GRUB and the
  live kernel to SDDM in QEMU (143.4 seconds).

These real package tests were confined to the Debian build chroot, including a
dedicated storetest user for AppImage operations. They did not upgrade the VPS.
The system-update resolver was checked against the editable AmogOS rootfs.
Interactive polkit authentication and physical-desktop validation remain for
normal user testing on the ISO.

## Artifacts and logs

Source: /srv/chocolatier/apps/app_store

Package: /srv/chocolatier/apps/app_store/dist/amogos-store_0.1.1_amd64.deb

- /srv/chocolatier/logs/store-integration.log
- /srv/chocolatier/logs/store-linux-build.log
- /srv/chocolatier/logs/store-unit-tests.log
- /srv/chocolatier/logs/store-comment-audit.log
- /srv/chocolatier/logs/store-native-check.log
- /srv/chocolatier/logs/AmogOS-2-Pro-App-Store-checkpoint007-verification.json
- /srv/chocolatier/logs/checkpoint007-boot-result.json
- /srv/chocolatier/logs/store-source-sha256.json

Development ISO:

    /srv/chocolatier/output/AmogOS-2-Pro-App-Store-checkpoint007.iso

Windows screenshots under build/previews include the home screen in both themes,
system updates, sources, app source selection, active queue, and Flatpak-required
screen. The project keeps generated Windows build data on D: through junctions
because C: has very little free space.


## Staged fixes: 0.1.2

No ISO was rebuilt for these changes. The updated package is installed in the editable rootfs and copied to the Windows repo folder.

- 21 backend tests and 10 Flutter tests passed; static analysis is clean.
- All 69,966 candidate packages in the build chroot are browsable, including page 1001 and the final page (2915). Full-page requests took about 1.5 seconds there.
- Repository enumeration includes origins of non-default versions. Description search and enabled foreign architectures have regression coverage.
- AppImage files and menu launchers use executable permissions. Existing receipts are repaired from cached category metadata.
- VLC AppImageHub listing 1231861 opened from both the Store backend and its generated desktop menu entry. Removing its executable bits before the menu test exercised permission repair.
- Listing 2194959 has an upstream packaging defect: libvlc.so.5 is absent from its AppImage. The Store and menu launcher now report that error and preserve a launch log. It is not presented as a successful launch.
- A listing selector exposes alternative AppImageHub entries. VLC AppImage details also resolve the verified APT and Flatpak alternatives.
- Existing checkpoint009.iso still matches its original SHA-256 checksum.

Native screenshots and menu results are copied to the Windows build/previews directory. The isolated test packages were confined to the build chroot, not the VPS host.

## Staged 0.1.3 checks

The Windows and Debian 13 Linux release builds passed static analysis and all
16 Flutter tests. All 31 backend tests passed, including complete installed
inventory, selected APT updates, source failures, scoped Flatpak references and
reviewed origins, and AppImage build selection. Responsive tests cover every
page in both themes at 360×640, 640×480, 800×600 and 1024×600 with 130% text.
Native Linux starts within 608×416 on a 640×480 display with amogos.appstore as
WM_CLASS. The installed inventory matched all 904 dpkg-installed packages in
the isolated build environment and all four system Flatpak runtimes. Real user
Flatpak install, selected update and removal passed with a private test D-Bus.
The updated DEB is staged in the editable rootfs. No ISO was rebuilt.

## App Store 0.1.5

This is an App Store-only release for AmogOS 2.1. Other AmogOS packages and the ISO are unchanged.

- Repository preferences now cover only binaries built from the selected source package. Real GIMP installation passed from Debian main followed by the security repository; removal and dpkg audit also passed. Plans for both GIMP and Krita repositories and Audacity passed on a fresh 2.1 target. Unrelated dependency security versions retain their normal APT policy.
- Repair explicitly reviews a reinstall plus missing recommended dependencies. Actual repairs passed for GIMP, VLC, Krita and Audacity.
- Native launches use GIO desktop entry handling and save early errors instead of discarding output. They query dpkg directly rather than allocating an APT cache. Missing display endpoints can be recovered from the current user's desktop session; inherited Qt plugin search paths are removed for the child process.
- Real windows opened for VLC, Krita and Audacity under KWin/XWayland and GIMP under native Wayland, with the launcher's DISPLAY deliberately empty and an invalid inherited QT_PLUGIN_PATH.
- Portable VLC AppImageHub listing 1231861 opened with FUSE deliberately unavailable. The fallback extracts with bounded memory and reuses the AppDir until the download changes.
- Both current artifacts in unofficial VLC listing 2194959 are incompatible: the first omits libvlc.so.5, and the second cannot load its graphical interface on Debian. Their exact published checksums are withheld, and installed copies offer the portable replacement. Future uploads with different checksums are not blocked.
- Failed package reviews and empty transactions provide visible feedback. Installed AppImages allow a reviewed reinstall or build change. Uninstalling, updating and repairing have distinct queue labels.
- Queue confirmations use a bottom-centred root-layer pill above pages and dialogs. It replaces the previous notice, has View queue and dismiss actions, and expires after four seconds without waiting for navigation or focus. Widget tests verify placement and interaction at widths 400 and 1280 and prove timer replacement and dismissal.

Release checks: 39 backend tests, 24 Flutter tests, clean Flutter analysis, one-comment source audit, Linux release build, isolated real APT transactions and Plasma launch checks. Package and archive verification are recorded in the published release report.

## App Store 0.1.6

An installed AmogOS 2.1 VirtualBox guest showed the confirmed failure: restarting the desktop caused its user manager to kill the Store helper, apt-get, dpkg and update-mime-database together. That left shared-mime-info unconfigured until a manual dpkg command completed it. The journal did not establish an out-of-memory kill as the cause of the desktop restart.

System APT and Flatpak transactions now run in independent system services. Closing the Store or restarting the desktop does not terminate their process groups. Root-owned, owner-readable journals retain progress and completion, and reopening the Store reconnects to the queue without replaying transactions. User Flatpak operations retain their existing account scope.

Updates offers Repair interrupted installation. The review lists packages awaiting configuration; only after approval does the worker resume dpkg configuration and check package consistency. A normal install reports pending configuration and points to that repair action. Existing application Repair also includes pending configuration in its review.

APT caches are explicitly closed before package commands run. Workers use lower CPU priority and a 256 MiB soft memory threshold; there is no hard memory cap that would force configuration to fail. Atomic progress snapshots preserve the owner's read ACL, and other users cannot read private requests or another user's receipts. Legacy root:root 0775 state parents are migrated to 0755; unsafe ownership and world-writable directories are refused.

Validation includes 48 backend tests, 26 Flutter tests, clean analysis and a 103-file comment audit. A disposable real systemd target started from an unpacked package, terminated the Store-side client during its maintainer script, then verified independent completion, an empty dpkg audit, owner reconnection, and isolation from another user. The existing pill, source selection and responsive-layout tests continue to pass. This release changes only amogos-store; AmogOS remains 2.1 and no ISO is rebuilt.
