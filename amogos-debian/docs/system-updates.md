# AmogOS 2.1 system update

The signed `amogos-update` 2.1.0-3 package upgrades AmogOS 2.0 and repairs existing 2.1 installations through normal APT updates. It depends on App Store 0.1.4 or newer and `amogos-system` 2.1.0-2 or newer. The OS version remains 2.1. No ISO reinstall is required.

    sudo apt update
    sudo apt full-upgrade
    sudo reboot

The App Store's system updates use the same signed package versions. Online AmogOS Installer installations also perform the full upgrade and verify that no updates or package configuration remain pending.

## Changes

- Sets `OS_VERSION` and `VERSION_ID` to 2.1, updates the other AmogOS identity files, and removes the old identity comment. The local dpkg diversion retains AmogOS identity across Debian base-files upgrades; the vendor backup is preserved.
- Restores normal APT recommendations and provides Qt 5/Qt 6 Wayland plugins, XWayland and X11 support for current and future desktop packages. It does not force a global Qt platform override. VLC 3 and Krita use XWayland in a Wayland session; reboot after the update to refresh the desktop display environment.
- Repairs missing standard Debian main repository entries while retaining custom repositories.
- Reduces App Store catalog and image memory, bounds result pages and logs, and fixes repository-specific dependency planning and package progress descriptors.
- Removes Calamares and AmogOS Installer only on installed systems. Live sessions retain both installation tools. No autoremove is used.
- Corrects the filesystem root to root:root, mode 0755. An incorrectly user-owned root prevented systemd-tmpfiles from creating X11 sockets, leaving VLC and Krita unable to connect to XWayland. The repair changes only the root inode and never recursively changes user files. Restart an affected desktop after updating.
- Enables an early root ownership guard in both live and installed boots, before systemd-tmpfiles. Installer 0.1.6 also normalizes the target root immediately after extraction; ISO tools reject incorrect root metadata in both the source directory and staged SquashFS image.
- Adds `/usr/bin/amogos-credits`, owned by the persistent system package. It prints `AmogOS 2.1 Pro (Debian edition) developed by CursedMC64 and techtimefor.` and remains after installer removal.

`amogos-system` owns the Plymouth animation, credits, root ownership guard and persistent low-memory configuration. Desktop themes, wallpaper and Plasma settings are retained. The cleanup service runs before the display manager on an installed boot; it also runs after an online system migration when systemd is available. It waits for the package manager's lock before removing live tools. Installer 0.1.6 removes the tools from its target after bootloader setup, and bundles system package 2.1.0-2 for offline installations. A current or newer target system package is retained.

## Repeating the update

On a healthy 2.1 or newer OS version, `sudo amogos-update` prints exactly:

    You are already on the latest AmogOS version

It makes no identity or repository changes. Root ownership maintenance still runs on 2.1 and newer; if it repairs the root, it reports that a restart is needed instead. Reconfiguring a successfully applied package also prints the latest-version message. Package downgrades cannot reset migration history.

The package's postinst records its version atomically in `/var/lib/amogos-update/applied-version` only after success. Failures leave the previous stamp intact and dpkg reports unfinished configuration. After repairing the underlying issue, `sudo dpkg --configure -a` retries it.

## Future releases

Change the migration and bump its package version, target OS version and dependencies together. Account for users skipping releases. Rebuild the DEB and signed archive, validate, then commit sources, immutable package files and indexes together. A changed script or Git commit alone does not constitute an APT update. Existing package versions cannot be replaced with different contents.

Do not invoke APT or dpkg installation from a migration while its postinst holds the package-manager lock. Declare package dependencies in control files and defer removal to a separate service.

    python3 scripts/validate-repository.py
    sudo python3 tests/test-updater.py
    python3 tests/test-migration.py
    sudo python3 tests/test-system.py
    python3 tests/test-apt.py

The lifecycle test uses real dpkg in a disposable minimal chroot; migration tests check 2.0 upgrades and unchanged identity files on 2.1, 2.1.1, 2.2 and 3.0. System tests reproduce tmpfiles failure against a user-owned root, verify shallow repair and credits, and reject incorrect directory and image metadata. Install squashfs-tools for these tests. Full desktop and installer-target integration results are retained with the release verification artifacts.
