# AmogOS Debian package archive

A signed APT repository for **AmogOS 2 Pro / Debian 13 amd64**.
The archive contains all four AmogOS applications, amogos-update, and
amogos-archive-keyring. See [PACKAGES.md](PACKAGES.md) for exact versions
and direct downloads.

## Install the repository

Once GitHub Pages has published this checkout:

    curl --fail --location --output install.sh \
      https://amogosbuild.github.io/amogos-debian/install.sh
    less install.sh
    sudo sh install.sh
    sudo apt install amogos-store amogos-music amogos-notes

The setup script verifies a pinned SHA-256 checksum for the keyring DEB,
installs its public signing key and scoped Deb822 source, then refreshes APT
and installs the updater. Keep your existing Debian sources for dependencies.
The installer package is also available for live installation media.

The installed source is:

    Types: deb
    URIs: https://amogosbuild.github.io/amogos-debian
    Suites: stable
    Components: main
    Architectures: amd64
    Signed-By: /usr/share/keyrings/amogos-archive-keyring.gpg

The amd64 index includes architecture-independent packages as well. Restricting
the source to amd64 avoids foreign-architecture fetches on Steam-enabled systems.
There is no trusted=yes, global apt-key, or unsigned archive bypass.

Archive signing fingerprint:

    AD0DEB95462DBF4C6C4F3A5571447013FAF2C774

The [public key](keyrings/amogos-archive-keyring.asc), signed
[InRelease](dists/stable/InRelease), detached signature, compressed indexes,
SHA-256/SHA-512 by-hash indexes and [package checksums](SHA256SUMS) are included.

## Build and sign changes

Use Linux with Python 3.11 or newer, dpkg-dev, GnuPG and the standard coreutils.
The initial private signing key remains in the root-only VPS directory
/srv/chocolatier/repository-keys/amogos-archive. Back up that directory securely;
never add it, private exports or revocation certificates to this repository.

To update an application, copy its newly built DEB into
pool/main/a/PACKAGE-NAME/. Keep existing versioned filenames intact.
The migration and keyring package sources live in packages/.

    python3 scripts/build-repository.py \
      --gnupg-home /srv/chocolatier/repository-keys/amogos-archive \
      --signing-key AD0DEB95462DBF4C6C4F3A5571447013FAF2C774
    python3 scripts/validate-repository.py
    sudo python3 tests/test-updater.py
    python3 tests/test-apt.py

Run these commands from amogos-debian/. The builder packages maintained
sources, generates the APT indexes, signs the Release files, and refreshes the
catalog and checksum-pinned setup script. A changed source package must have
a higher Version:; rebuilding different contents under an existing version
is rejected. Identical source-package rebuilds preserve the original DEB bytes.
Older immutable by-hash indexes remain available across repository rebuilds.

Then commit the changed pool files, metadata and sources together. GitHub Pages
serves the committed files; changing a script alone does not publish a new
Debian package. No Flutter rebuild is needed for amogos-update.

The signing key expires in October 2028. Arrange key rotation before expiry.
Distribute an overlapping old/new public keyring while the old key is still
trusted before switching the Release signer.

## Validation and OS integration

validate-repository.py checks both signatures, compressed indexes, every DEB
checksum, immutable indexes and source-package consistency. test-apt.py uses
isolated APT state and a loopback-only HTTP server to check update detection and
authenticated downloads, including rejection of a corrupted package.
test-updater.py uses a disposable minimal chroot and actual dpkg install,
upgrade, failure/retry, reinstall, downgrade and purge operations.

The application DEBs remain the tested Linux builds: Installer and App Store
use Flutter 3.47.6; Music and Notes use Flutter 3.0.5. The staged OS installs the
keyring and updater as ordinary packages, and both installer copy paths retain
them. Public network updates become usable after this checkout is published.

See [system-updates.md](docs/system-updates.md) before adding a system migration.
