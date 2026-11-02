# Read-only ISO checks compare the shipped store, helper, and original character assets to their sources.
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import tempfile

w=pathlib.Path("/srv/chocolatier")
name=sys.argv[1]
if not re.fullmatch(r"[A-Za-z0-9._-]+\.iso",name):
    raise SystemExit("Use an ISO basename.")
iso=w/"output"/name
project=w/"apps/app_store"
subprocess.run(["sha256sum","-c",str(iso)+".sha256"],cwd=iso.parent,check=True)
checks=[]
with tempfile.TemporaryDirectory(prefix="verify-store-",dir=w/"cache") as folder:
    medium=pathlib.Path(folder)
    subprocess.run(["mount","-o","loop,ro",str(iso),folder],check=True)
    try:
        squash=medium/"live/filesystem.squashfs"
        def read(path):
            return subprocess.check_output(["unsquashfs","-cat",str(squash),path])
        pairs=[("usr/lib/amogos-store/backend/"+str(p.relative_to(project/"backend")),p) for p in (project/"backend").rglob("*.py")]
        pairs += [("usr/lib/amogos-store/app/amogos_store",project/"build/linux/x64/release/bundle/amogos_store"),("usr/libexec/amogos-store-helper",project/"packaging/amogos-store-helper"),("usr/share/applications/amogos.appstore.desktop",project/"packaging/amogos.appstore.desktop")]
        pairs += [("usr/lib/amogos-store/app/data/flutter_assets/assets/characters/"+p.name,p) for p in (project/"assets/characters").glob("*.png")]
        for path,source in pairs:
            actual=read(path)
            if actual!=source.read_bytes():
                raise AssertionError(path+" differs from the build/source")
            checks.append(dict(path=path,sha256=hashlib.sha256(actual).hexdigest()))
        assert b'PRETTY_NAME="AmogOS 2 Pro"' in read("etc/os-release")
        assert len(read("etc/ssl/certs/ca-certificates.crt"))>50000
        remote=read("var/lib/flatpak/repo/config")
        assert b'[remote "flathub"]' in remote and b'https://dl.flathub.org/repo' in remote
        assert b"storetest:" not in read("etc/passwd")
        assert b"AmogOS 2 Pro" in read("usr/share/plymouth/themes/amogos2pro/amogos2pro.script")
        assert b"Name=Install AmogOS 2 Pro" in read("usr/share/applications/amogos.installer.desktop")
        assert read("usr/bin/amogos-appstore")== (project/"packaging/amogos-appstore").read_bytes()
        for app_id in ("amogos.appstore", "amogos.installer", "amogos.music"):
            assert ("StartupWMClass="+app_id).encode() in read("usr/share/applications/"+app_id+".desktop")
        music=w/"apps/music"
        assert read("usr/lib/amogos-music/amogos_music")== (music/"build/linux/x64/release/bundle/amogos_music").read_bytes()
        assert read("usr/bin/amogos-music")== (music/"packaging/linux/amogos-music").read_bytes()
        assert b"Package: amogos-music\nStatus: install ok installed" in read("var/lib/dpkg/status")
    finally:
        subprocess.run(["umount",folder],check=True)
report=dict(passed=True,iso=str(iso),checks=checks)
out=w/"logs"/(iso.stem+"-store-verification.json")
out.write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps(dict(passed=True,report=str(out))),flush=True)
