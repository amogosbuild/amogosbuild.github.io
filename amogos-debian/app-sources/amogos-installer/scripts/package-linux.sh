#!/bin/bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$project/build/linux/x64/release/bundle"
test -x "$bundle/amogos_installer"
stage="$(mktemp -d)"
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/DEBIAN" "$stage/usr/lib/amogos-installer/app" "$stage/usr/lib/amogos-installer/backend" "$stage/usr/libexec" "$stage/usr/bin" "$stage/usr/share/applications" "$stage/usr/share/icons/hicolor/256x256/apps" "$stage/usr/share/polkit-1/actions"
cp "$project/packaging/control" "$stage/DEBIAN/control"
core="${AMOGOS_SYSTEM_DEB:-$project/../system/dist/amogos-system_2.1.0-2_all.deb}"
if ! test -f "$core"; then
    core="$project/../../pool/main/a/amogos-system/amogos-system_2.1.0-2_all.deb"
fi
install -D -m644 "$core" "$stage/usr/share/amogos-installer/amogos-system.deb"
test "$(dpkg-deb -f "$core" Package)" = amogos-system
dpkg --compare-versions "$(dpkg-deb -f "$core" Version)" ge 2.1.0-2
cp -a "$bundle/." "$stage/usr/lib/amogos-installer/app/"
cp -a "$project/backend/." "$stage/usr/lib/amogos-installer/backend/"
find "$stage" -type d -name __pycache__ -prune -exec rm -rf -- {} +
install -m 755 "$project/packaging/amogos-installer-helper" "$stage/usr/libexec/"
install -m 755 "$project/packaging/amogos-installer" "$stage/usr/bin/"
install -m 644 "$project/packaging/amogos.installer.desktop" "$stage/usr/share/applications/"
install -m 644 "$project/packaging/org.amogos.installer.policy" "$stage/usr/share/polkit-1/actions/"
cp "$project/assets/icons/amogos-installer.png" "$stage/usr/share/icons/hicolor/256x256/apps/amogos-installer.png"
cp "$project/assets/icons/amogos-installer.png" "$stage/usr/share/icons/hicolor/256x256/apps/amogos.installer.png"
install -D -m644 "$project/assets/icons/amogos-installer.png" "$stage/usr/share/pixmaps/amogos-installer.png"
mkdir -p "$stage/usr/share/doc/amogos-installer"
cp "$project/third_party/"*.txt "$stage/usr/share/doc/amogos-installer/"
chmod -R go-w "$stage"
chmod 755 "$stage"
mkdir -p "$project/dist"
dpkg-deb --root-owner-group --build "$stage" "$project/dist/"
