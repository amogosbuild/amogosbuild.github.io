# Read-only ISO verification compares the packaged app, backend, and splash against maintained sources.
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import tempfile

workspace = pathlib.Path("/srv/chocolatier")
name = sys.argv[1]
assert re.fullmatch(r"[A-Za-z0-9._-]+\.iso", name)
iso = workspace/"output"/name
source = workspace/"apps/installer"
subprocess.run(["sha256sum", "-c", str(iso)+".sha256"], cwd=iso.parent, check=True)
checks = []
with tempfile.TemporaryDirectory(prefix="verify-checkpoint-", dir=workspace/"cache") as folder:
    medium = pathlib.Path(folder)
    subprocess.run(["mount", "-o", "loop,ro", str(iso), folder], check=True)
    try:
        squash = medium/"live/filesystem.squashfs"
        def embedded(path):
            return subprocess.run(["unsquashfs", "-cat", str(squash), path], check=True, stdout=subprocess.PIPE).stdout
        pairs = [("usr/lib/amogos-installer/backend/amogos_install/"+p, source/"backend/amogos_install"/p) for p in ("bootloaders.py", "boot_planner.py", "planner.py", "installer.py")]
        pairs += [("usr/share/plymouth/themes/amogos2pro/"+p.name, p) for p in (source/"boot/plymouth/amogos2pro").iterdir() if p.is_file()]
        pairs += [("usr/lib/amogos-installer/app/amogos_installer", source/"build/linux/x64/release/bundle/amogos_installer")]
        for path, original in pairs:
            data = embedded(path)
            assert data == original.read_bytes(), path+" differs from the source/build"
            checks.append(dict(path=path, sha256=hashlib.sha256(data).hexdigest()))
        assert b'PRETTY_NAME="AmogOS 2 Pro"' in embedded("etc/os-release")
        assert b"Theme=amogos2pro" in embedded("etc/plymouth/plymouthd.conf")
        assert b"Name=Install AmogOS 2 Pro" in embedded("usr/share/applications/amogos.installer.desktop")
        menu = (medium/"boot/grub/grub.cfg").read_text()
        assert "AmogOS 2 Pro Live" in menu and "boot=live quiet splash" in menu
        initrd = subprocess.run(["lsinitramfs", str(medium/"live/initrd")], check=True, text=True, stdout=subprocess.PIPE).stdout
        for required in ("themes/amogos2pro/amogos2pro.script", "themes/amogos2pro/rail.png", "themes/amogos2pro/slider.png", "plymouth/script.so", "plymouth/label-pango.so"):
            assert required in initrd, required
    finally:
        subprocess.run(["umount", folder], check=True)
report = dict(iso=str(iso), passed=True, embedded=checks, checks=["SHA-256", "compiled Linux app", "boot selection backend", "Plymouth assets", "live initramfs", "branding and launchers"])
output = workspace/"logs"/(iso.stem+"-installer-verification.json")
output.write_text(json.dumps(report, indent=2)+"\n")
print(json.dumps(dict(passed=True, iso=str(iso), report=str(output))), flush=True)
