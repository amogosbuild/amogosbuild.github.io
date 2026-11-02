# Build source packages, generate strong-hash indexes and sign the complete static APT archive.
import argparse
import datetime
import gzip
import hashlib
import json
import lzma
import os
import pathlib
import re
import subprocess
import tempfile
from archive import ROOT, build_package, package_info, place_package, run, sha256, write

parser = argparse.ArgumentParser()
parser.add_argument("--signing-key", required=True, help="Full fingerprint of the archive signing key")
parser.add_argument("--gnupg-home", required=True, type=pathlib.Path, help="Private GnuPG directory outside this repository")
arguments = parser.parse_args()
fingerprint = arguments.signing_key.upper()
if not re.fullmatch(r"[0-9A-F]{40}|[0-9A-F]{64}", fingerprint):
    parser.error("Use a full GPG fingerprint")
home = arguments.gnupg_home.resolve()
if home.is_relative_to(ROOT.parent.resolve()):
    parser.error("Keep private signing keys outside the public repository")
gpg = ["gpg", "--homedir", str(home), "--batch", "--yes", "--local-user", fingerprint]
public = run([*gpg, "--export-options", "export-minimal", "--export", fingerprint])
if not public:
    raise SystemExit("The public signing key could not be exported")
write(ROOT / "keyrings/amogos-archive-keyring.gpg", public)
write(ROOT / "keyrings/amogos-archive-keyring.asc", run([*gpg, "--armor", "--export-options", "export-minimal", "--export", fingerprint]))
write(ROOT / "keyrings/fingerprint.txt", fingerprint + "\n")
with tempfile.TemporaryDirectory(prefix=".repository-build-", dir=ROOT) as temporary:
    temporary = pathlib.Path(temporary)
    for name in ("amogos-system", "amogos-update", "amogos-archive-keyring"):
        place_package(build_package(ROOT / "packages" / name, temporary, public_key=public))
    packages = sorted((ROOT / "pool").rglob("*.deb"))
    expected = {"amogos-installer", "amogos-store", "amogos-music", "amogos-notes", "amogos-system", "amogos-update", "amogos-archive-keyring"}
    actual = {package_info(path)["Package"] for path in packages}
    if not expected.issubset(actual):
        raise SystemExit("Missing AmogOS packages: " + ", ".join(sorted(expected - actual)))
    index = run(["dpkg-scanpackages", "--multiversion", "pool", "/dev/null"], cwd=ROOT)
    paths = {
        "main/binary-amd64/Packages": index,
        "main/binary-amd64/Packages.gz": gzip.compress(index, mtime=0),
        "main/binary-amd64/Packages.xz": lzma.compress(index),
    }
    now = datetime.datetime.now(datetime.timezone.utc)
    release = [
        "Origin: AmogOS",
        "Label: AmogOS 2 Pro",
        "Suite: stable",
        "Codename: chocolatier",
        "Version: 2.1",
        "Date: " + now.strftime("%a, %d %b %Y %H:%M:%S +0000"),
        "Architectures: amd64",
        "Components: main",
        "Acquire-By-Hash: yes",
        "Description: AmogOS 2 Pro applications and versioned system updates for Debian 13",
    ]
    for algorithm in ("SHA256", "SHA512"):
        release.append(algorithm + ":")
        for path, data in sorted(paths.items()):
            release.append(" " + hashlib.new(algorithm.lower(), data).hexdigest() + " " + str(len(data)) + " " + path)
    write(temporary / "Release", "\n".join(release) + "\n")
    subprocess.run([*gpg, "--digest-algo", "SHA256", "--clearsign", "--output", str(temporary / "InRelease"), str(temporary / "Release")], check=True)
    subprocess.run([*gpg, "--digest-algo", "SHA256", "--armor", "--detach-sign", "--output", str(temporary / "Release.gpg"), str(temporary / "Release")], check=True)
    distribution = ROOT / "dists/stable"
    for path, data in paths.items():
        write(distribution / path, data)
        for algorithm in ("SHA256", "SHA512"):
            write(distribution / pathlib.Path(path).parent / "by-hash" / algorithm / hashlib.new(algorithm.lower(), data).hexdigest(), data)
    for name in ("Release", "InRelease", "Release.gpg"):
        os.replace(temporary / name, distribution / name)
    records = []
    for path in packages:
        info = package_info(path)
        records.append(dict(package=info["Package"], version=info["Version"], architecture=info["Architecture"], filename=path.relative_to(ROOT).as_posix(), bytes=path.stat().st_size, sha256=sha256(path)))
    manifest = dict(origin="AmogOS", suite="stable", codename="chocolatier", supportedSystem="Debian 13 amd64", signingFingerprint=fingerprint, generatedUtc=now.isoformat(), packages=records)
    write(ROOT / "repository.json", json.dumps(manifest, indent=2) + "\n")
    write(ROOT / "SHA256SUMS", "".join(record["sha256"] + "  " + record["filename"] + "\n" for record in records))
    keyring = next(record for record in records if record["package"] == "amogos-archive-keyring")
    installer = """#!/bin/sh
set -eu
if [ "$(id -u)" != 0 ]; then
    printf '%s\\n' 'Run this script as root after reviewing it.' >&2
    exit 1
fi
command -v curl >/dev/null
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
curl --fail --location --proto '=https' --tlsv1.2 --output "$temporary/keyring.deb" 'https://amogosbuild.github.io/amogos-debian/@FILE@'
printf '%s  %s\\n' '@SHA256@' "$temporary/keyring.deb" | sha256sum -c -
apt-get install --no-install-recommends -y "$temporary/keyring.deb"
apt-get -o APT::Update::Error-Mode=any update
apt-get install --no-install-recommends -y amogos-update
"""
    write(ROOT / "install.sh", installer.replace("@FILE@", keyring["filename"]).replace("@SHA256@", keyring["sha256"]), 0o755)
subprocess.run(["python3", str(ROOT / "scripts/render-catalog.py")], check=True)
print("Signed", len(records), "packages with", fingerprint)
