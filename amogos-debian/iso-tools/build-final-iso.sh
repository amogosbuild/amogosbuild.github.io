#!/bin/bash
set -euo pipefail
workspace=$(realpath -e "${AMOGOS_BUILD_DIR:?Set AMOGOS_BUILD_DIR to your prepared build workspace}")
test "$workspace" != /
name=${1:-AmogOS-2.1-Pro-toppat-$(date -u +%F).iso}
[[ "$name" =~ ^[A-Za-z0-9._-]+\.iso$ ]] || { echo "Use an ISO filename without directories"; exit 2; }
root="$workspace/rootfs"
test "$(realpath -e "$root")" = "$root"
grep -q '^ID=amogos$' "$root/etc/os-release"
test ! -e "$workspace/output/$name"
exec 9>"$workspace/logs/rootfs.lock"
flock -x 9
python3 "$workspace/scripts/verify-root.py" --directory "$root"
if findmnt -rn -o TARGET | grep -E "^$root/"; then exit 1; fi
test ! -e "$root/usr/sbin/policy-rc.d"
test ! -e "$root/var/lib/dkms/mok.key"
test ! -e "$root/AmogOS2-LiveSystem-Mark1.iso"
rm -f "$root/var/cache/apt/pkgcache.bin" "$root/var/cache/apt/srcpkgcache.bin"
stage=$(mktemp "$workspace/cache/final-filesystem.XXXXXX.squashfs")
trap 'test ! -f "$stage" || rm -f -- "$stage"' EXIT
mksquashfs "$root" "$stage" -noappend -comp zstd -b 262144 -Xcompression-level 15 -processors 4 -mem 2G -no-progress
python3 "$workspace/scripts/verify-root.py" --squashfs "$stage"
chmod 444 "$stage"
mv "$stage" "$workspace/iso-tree/live/filesystem.squashfs"
"$workspace/scripts/build-iso" "$name"
printf '%s\n' "$workspace/output/$name"
