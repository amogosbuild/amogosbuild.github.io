# AmogOS 2 Pro repositories

The Debian archive provides the AmogOS Installer, App Store, Music and Notes,
plus a versioned system update package. It targets **Debian 13 amd64**.

| Application | Package | Application ID | Terminal command |
| --- | --- | --- | --- |
| Installer | amogos-installer | amogos.installer | amogos-installer |
| App Store | amogos-store | amogos.appstore | amogos-appstore |
| Music | amogos-music | amogos.music | amogos-music |
| Notes | amogos-notes | amogos.notes | amogos-notes |

- [Debian repository setup and maintenance](amogos-debian/README.md)
- [Package versions and direct DEB downloads](amogos-debian/PACKAGES.md)
- [How system update migrations work](amogos-debian/docs/system-updates.md)
- [Public package catalog](https://amogosbuild.github.io/amogos-debian/)
- [AmogOS 2.x ISO Builder](https://github.com/amogosbuild/AmogOS-2.x-Builder) — complete Debian image build configuration; Arch is reserved.

The amogos-arch directory remains reserved for the future Arch project.
Debian supplies the ordinary system packages; this archive adds AmogOS packages.

## Publishing this checkout

Commit the complete repository contents, including .github, .gitattributes
and .nojekyll. Enable **Settings → Pages → Deploy from a branch → main →
/(root)**. GitHub Pages must finish publishing before clients can use the
public APT URL. The committed archive is already signed and indexed.

The validation workflow checks signatures, package hashes, source-package
synchronization, real APT downloads, and the updater lifecycle. It does not
publish changes, access a signing secret, or alter package versions.

Private signing keys are kept outside this checkout and are never part of
the downloadable repository ZIP.
