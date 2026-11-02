#!/bin/bash
set -euo pipefail
workspace=${1:-/srv/chocolatier}
test "$workspace" = /srv/chocolatier
project="$workspace/apps/installer"
root="$workspace/rootfs"
grep -q '^ID=amogos$' "$root/etc/os-release"
test -x "$workspace/enter-rootfs"
cp -a "$project/boot/plymouth/amogos2pro" "$root/usr/share/plymouth/themes/"
find "$root/usr/share/plymouth/themes/amogos2pro" -type d -exec chmod 755 {} +
find "$root/usr/share/plymouth/themes/amogos2pro" -type f -exec chmod 644 {} +
mkdir -p "$root/etc/plymouth"
cat > "$root/etc/plymouth/plymouthd.conf" <<'EOF'
[Daemon]
Theme=amogos2pro
ShowDelay=0
DeviceTimeout=8
EOF
python3 - <<'PY'
from pathlib import Path
root=Path('/srv/chocolatier/rootfs')
path=root/'etc/os-release'
values={'PRETTY_NAME':'"AmogOS 2 Pro 2.1 (toppat)"','NAME':'"AmogOS 2 Pro"','VERSION_ID':'"2.1"','OS_VERSION':'"2.1"','VERSION':'"2.1 (toppat)"'}
lines=[line.split('=',1)[0]+'='+values[line.split('=',1)[0]] if line.split('=',1)[0] in values else line for line in path.read_text().splitlines() if not line.startswith('# AmogOS identity is retained')]
present={line.split('=',1)[0] for line in lines if '=' in line}
lines.extend(key+'='+value for key,value in values.items() if key not in present)
path.write_text('\n'.join(lines)+'\n')
(root/'etc/issue').write_text('AmogOS 2 Pro 2.1 (toppat) \\n \\l\n\n')
(root/'etc/issue.net').write_text('AmogOS 2 Pro 2.1 (toppat)\n')
path=Path('/srv/chocolatier/iso-tree/boot/grub/grub.cfg')
path.write_text(path.read_text().replace('AmogOS Live','AmogOS 2 Pro Live'))
PY
kernel="$(find "$root/boot" -maxdepth 1 -type f -name 'vmlinuz-*' -printf '%f\n' | sort -V | tail -n 1)"
version="${kernel#vmlinuz-}"
test -n "$version"
test -d "$root/lib/modules/$version"
"$workspace/enter-rootfs" bash -euc 'plymouth-set-default-theme amogos2pro; update-initramfs -u -k "$1"' -- "$version"
install -m644 "$root/boot/$kernel" "$workspace/iso-tree/live/vmlinuz"
install -m644 "$root/boot/initrd.img-$version" "$workspace/iso-tree/live/initrd"
printf '%s\n' "$version" > "$workspace/iso-tree/live/kernel-version"
