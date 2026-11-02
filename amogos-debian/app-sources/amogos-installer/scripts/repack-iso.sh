#!/bin/bash
set -euo pipefail
workspace=/srv/chocolatier
filename=${1:-AmogOS-Chocolatier-Installer-$(date -u +%Y%m%dT%H%M%SZ).iso}
[[ "$filename" =~ ^[A-Za-z0-9._-]+\.iso$ ]] || { echo "Use a filename without directories"; exit 2; }
test ! -e "$workspace/output/$filename"
exec 9>"$workspace/logs/rootfs.lock"
flock -n 9 || { echo "Close the rootfs chroot before repacking"; exit 1; }
if findmnt -rn -o TARGET | grep -E "^$workspace/rootfs/"; then
    echo "The rootfs still has mounted filesystems"
    exit 1
fi
test ! -e "$workspace/rootfs/usr/sbin/policy-rc.d"
stage="$(mktemp "$workspace/cache/filesystem.XXXXXX.squashfs")"
trap 'test ! -f "$stage" || rm -f -- "$stage"' EXIT
mksquashfs "$workspace/rootfs" "$stage" -noappend -comp gzip -b 131072 -processors 2 -no-progress
chmod 444 "$stage"
if ! test -e "$workspace/cache/original-filesystem.squashfs"; then
    ln "$workspace/iso-tree/live/filesystem.squashfs" "$workspace/cache/original-filesystem.squashfs"
fi
mv "$stage" "$workspace/iso-tree/live/filesystem.squashfs"
"$workspace/scripts/build-iso" "$filename"
