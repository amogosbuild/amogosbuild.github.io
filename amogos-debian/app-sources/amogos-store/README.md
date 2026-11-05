# AmogOS App Store

Complete Debian ISO builds are maintained in
[AmogOS-2.x-Builder](https://github.com/amogosbuild/AmogOS-2.x-Builder).

Flutter 3.47.6 App Store for AmogOS 2 Pro. The interface follows the supplied
reference: black background, rose sidebar, green install action, animated
selection dot, and bold selected navigation. Light mode is also included.

Browse APT repositories, Flathub, and AppImageHub. Each app offers only its
available APT, Flatpak, and AppImage formats. APT repositories can be filtered
and selected independently. The sidebar queue runs reviewed jobs one at a time.
Installed lists all installed APT packages, system/user Flatpak applications and runtimes, and AppImages managed by this store. Updates separates APT, Flatpak and AppImage updates with per-package selection and dependency review. A complete APT system upgrade remains available.

If Flatpak is missing, the store explains that it needs to be installed and
offers an APT installation. All seven supplied shoppers are bundled, including
session-stable semi-rare and rare appearances.

## Source and builds

    flutter pub get
    flutter analyze
    flutter test --concurrency=1
    powershell -File scripts/build-windows.ps1
    flutter build linux --release
    bash scripts/package-linux.sh
    python3 scripts/source_comments.py --normalize
    python3 -m unittest discover -s backend/tests -v

Windows is explicitly a design preview with sample catalog data. Package
changes are enabled only in the Linux build. The Windows build and SDK test
temporary files use a separate local output directory. The Windows build script
makes a fresh source copy to avoid stale compiler caches. Put Flutter on PATH,
or pass -FlutterCommand to select its executable, and use -OutputRoot to choose
the output directory. The native preview is under build/windows/x64/runner/Release
inside the generated build copy.

Application ID: amogos.appstore. Launch with amogos-appstore from a terminal.
The former amogos-store command remains an alias.

Linux package: dist/amogos-store_0.1.6_amd64.deb

The maintained source is organized under lib/, backend/, packaging/, and scripts/.
See docs/architecture.md for transaction behavior and docs/verification.md for
validation evidence. Each maintained source file has one comment.

The MCPI card uses the official supported Flathub build and links to:
https://gitea.thebrokenrail.com/minecraft-pi-reborn/minecraft-pi-reborn/releases/latest

ISO verification helpers require a prepared workspace selected by
AMOGOS_BUILD_DIR; application packaging alone does not assemble a complete ISO.


Compact windows use a scrolling navigation drawer and responsive grids. Pages and dialogs are tested at 360×640, 640×480, 800×600 and 1024×600 with 130% text. Native windows start within the monitor work area.
