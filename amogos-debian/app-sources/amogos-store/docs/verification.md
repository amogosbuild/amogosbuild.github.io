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
