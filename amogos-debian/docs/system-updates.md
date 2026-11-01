# Versioned AmogOS system changes

Amogos-update is an architecture-independent Debian package. The initial
/usr/bin/amogos-update exits successfully and makes no system changes.
Its current package version is 2.0.0-1.

## What happens during an OS update

1. APT refreshes the signed AmogOS index and finds a higher package version.
2. The user installs the available updates through the App Store or APT.
3. Dpkg replaces /usr/bin/amogos-update with the new packaged script.
4. The package's postinst configure invokes it as root.
5. Only after success is the version written atomically to
   /var/lib/amogos-update/applied-version.

This uses the same upgrade path as other OS packages. There is no background
watcher, raw GitHub script polling, remote shell execution, or boot-time rerun.
The initial package records its successful no-op version.

## Publish a future change

Edit packages/amogos-update/amogos-update, then increase Version: in its
control file, for example from 2.0.0-1 to 2.0.1-1. Rebuild and sign the
archive with scripts/build-repository.py, validate it, and commit the new
DEB, indexes, signatures and source together.

**A Git commit or a changed file hash alone is not an APT upgrade.**
The package version must increase. The builder rejects changes to a maintained
source package that reuse an existing version.

During automatic execution, the migration receives:

| Environment variable | Meaning |
| --- | --- |
| AMOGOS_UPDATE_FROM | Last successfully applied package version, or empty on first install |
| AMOGOS_UPDATE_TO | New version being configured |

Use these values if a release needs to migrate older states. Users can skip
several releases, so the latest script must account for all supported earlier
states or include the required earlier steps.

## Failure and repetition

Migrations must be idempotent and noninteractive. They may be retried after an
interruption and must preserve user data and intentional local settings.
Use a nonzero exit code on failure. A failure leaves the old success stamp
intact and dpkg reports the package as needing configuration; it does not
silently report the system as updated.

After resolving the underlying problem, sudo dpkg --configure -a retries
configuration. Reinstalling an already successful version does not rerun it.
A package downgrade does not roll back migration history or rerun an older
script. Purging the package removes its version stamp and packaged command;
other migration data is retained if its state directory is nonempty.

Do not call APT or dpkg from the migration script: the package manager already
holds its locks. Express package dependencies in control. Put dependency
or hardware-specific application work in its own package where appropriate.

Normally, let the package manager run migrations. The current terminal command
is harmless, but future migration code should not depend on being called
manually. Test changes with sudo python3 tests/test-updater.py and add
meaningful migration-specific tests before publishing them.

