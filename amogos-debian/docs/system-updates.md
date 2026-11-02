# AmogOS 2.1 system update

The signed `amogos-update` 2.1.0-2 package upgrades AmogOS 2.0 through normal APT updates. It depends on App Store 0.1.4 and the persistent `amogos-system` package. No ISO reinstall is required.

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

`amogos-system` owns the Plymouth animation and persistent low-memory configuration. Desktop themes, wallpaper and Plasma settings are retained. The cleanup service runs before the display manager on an installed boot; it also runs after an online system migration when systemd is available. It waits for the package manager's lock before removing live tools. Installer 0.1.5 removes the tools from its target after bootloader setup, and bundles the persistent system package for offline installations.

## Repeating the update

On 2.1 or any newer OS version, `sudo amogos-update` prints exactly:

    You are already on the latest AmogOS version

It makes no identity or repository changes. Reconfiguring a successfully applied package also prints that message. Package downgrades cannot reset migration history.

The package's postinst records its version atomically in `/var/lib/amogos-update/applied-version` only after success. Failures leave the previous stamp intact and dpkg reports unfinished configuration. After repairing the underlying issue, `sudo dpkg --configure -a` retries it.

## Future releases

Change the migration and bump its package version, target OS version and dependencies together. Account for users skipping releases. Rebuild the DEB and signed archive, validate, then commit sources, immutable package files and indexes together. A changed script or Git commit alone does not constitute an APT update. Existing package versions cannot be replaced with different contents.

Do not invoke APT or dpkg installation from a migration while its postinst holds the package-manager lock. Declare package dependencies in control files and defer removal to a separate service.

    python3 scripts/validate-repository.py
    sudo python3 tests/test-updater.py
    python3 tests/test-migration.py
    python3 tests/test-apt.py

The lifecycle test uses real dpkg in a disposable minimal chroot; migration tests check 2.0 upgrades and unchanged files on 2.1, 2.1.1, 2.2 and 3.0. Full desktop and installer-target integration results are retained with the release verification artifacts.
