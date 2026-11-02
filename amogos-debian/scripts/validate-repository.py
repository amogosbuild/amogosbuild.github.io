# Verify public signatures, every package/index hash and synchronization with maintained package sources.
import datetime
import email.utils
import gzip
import hashlib
import html.parser
import json
import lzma
import pathlib
import subprocess
import tempfile
import urllib.parse
from archive import ROOT, build_package, fields, package_contents, package_info, run, sha256


def require(condition, message):
    if not condition:
        raise SystemExit(message)


keyring = ROOT / "keyrings/amogos-archive-keyring.gpg"
fingerprint = (ROOT / "keyrings/fingerprint.txt").read_text().strip()
distribution = ROOT / "dists/stable"
with tempfile.TemporaryDirectory(prefix="amogos-verify-") as temporary:
    temporary = pathlib.Path(temporary)
    home = temporary / "gnupg"
    home.mkdir(mode=0o700)
    status = subprocess.run(["gpgv", "--homedir", str(home), "--status-fd", "1", "--keyring", str(keyring), "--output", str(temporary / "Release"), str(distribution / "InRelease")], check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
    require("[GNUPG:] VALIDSIG " + fingerprint + " " in status, "Unexpected Release signer")
    require((temporary / "Release").read_bytes() == (distribution / "Release").read_bytes(), "Signed and detached Release contents differ")
    subprocess.run(["gpgv", "--homedir", str(home), "--keyring", str(keyring), str(distribution / "Release.gpg"), str(distribution / "Release")], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
release = fields((distribution / "Release").read_text())
require(release.get("Origin") == "AmogOS" and release.get("Suite") == "stable" and release.get("Acquire-By-Hash") == "yes", "Incorrect Release identity")
require(release.get("Architectures") == "amd64", "Unexpected repository architecture")
date = email.utils.parsedate_to_datetime(release["Date"])
require(date <= datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1), "Release date is in the future")
index_names = {"main/binary-amd64/Packages", "main/binary-amd64/Packages.gz", "main/binary-amd64/Packages.xz"}
for algorithm in ("SHA256", "SHA512"):
    recorded = set()
    for row in release[algorithm].strip().splitlines():
        expected, size, name = row.split()
        path = pathlib.PurePosixPath(name)
        require(not path.is_absolute() and ".." not in path.parts, "Unsafe Release path")
        data = (distribution / name).read_bytes()
        require(len(data) == int(size) and hashlib.new(algorithm.lower(), data).hexdigest() == expected, "Index hash mismatch: " + name)
        require((distribution / path.parent / "by-hash" / algorithm / expected).read_bytes() == data, "Missing immutable index: " + name)
        recorded.add(name)
    require(recorded == index_names, "Missing or unexpected indexes")
directory = distribution / "main/binary-amd64"
index = (directory / "Packages").read_bytes()
require(gzip.decompress((directory / "Packages.gz").read_bytes()) == index, "Invalid gzip index")
require(lzma.decompress((directory / "Packages.xz").read_bytes()) == index, "Invalid xz index")
records = []
identities = set()
for paragraph in index.decode("utf-8").strip().split("\n\n"):
    item = fields(paragraph)
    path = pathlib.PurePosixPath(item["Filename"])
    require(path.parts[0] == "pool" and ".." not in path.parts and not path.is_absolute(), "Unsafe package path")
    package = ROOT / path
    require(package.is_file() and package.stat().st_size == int(item["Size"]) and sha256(package) == item["SHA256"], "Package checksum mismatch: " + str(path))
    info = package_info(package)
    require(all(info[field] == item[field] for field in ("Package", "Version", "Architecture")), "Package metadata mismatch")
    require(info["Architecture"] in ("all", "amd64"), "Unsupported package architecture")
    identity = (item["Package"], item["Version"], item["Architecture"])
    require(identity not in identities, "Duplicate package version")
    identities.add(identity)
    records.append(dict(package=item["Package"], version=item["Version"], architecture=item["Architecture"], filename=str(path), bytes=package.stat().st_size, sha256=item["SHA256"]))
required = {"amogos-installer", "amogos-store", "amogos-music", "amogos-notes", "amogos-system", "amogos-update", "amogos-archive-keyring"}
require(required.issubset({item["package"] for item in records}), "An AmogOS package is missing")
manifest = json.loads((ROOT / "repository.json").read_text())
require(manifest["signingFingerprint"] == fingerprint, "Manifest signer mismatch")
require(sorted(manifest["packages"], key=lambda p:p["filename"]) == sorted(records, key=lambda p:p["filename"]), "Repository manifest is stale")
with tempfile.TemporaryDirectory(prefix="amogos-source-check-") as temporary:
    for name in ("amogos-system", "amogos-update", "amogos-archive-keyring"):
        package = build_package(ROOT / "packages" / name, temporary, public_key=keyring.read_bytes())
        match = next((item for item in records if pathlib.Path(item["filename"]).name == package.name), None)
        require(match is not None and package_contents(package) == package_contents(ROOT / match["filename"]), "Rebuild the changed source package: " + name)
for path in ROOT.parent.rglob("*"):
    if ".git" in path.parts or not path.is_file():
        continue
    require(not any(part in (".gnupg", "private-keys-v1.d", "openpgp-revocs.d") for part in path.parts), "Private key directory in public repository")
    if path.suffix == ".asc":
        require(b"PRIVATE KEY" not in path.read_bytes(), "Private signing key in public repository")
require((ROOT.parent / ".nojekyll").is_file(), "The GitHub Pages static-file marker is missing")
class Links(html.parser.HTMLParser):
    def handle_starttag(self, tag, attributes):
        if tag != "a":
            return
        href = dict(attributes).get("href", "")
        if not href or href.startswith(("#", "https://", "http://")):
            return
        path = (ROOT / urllib.parse.unquote(href)).resolve()
        require(path.is_relative_to(ROOT) and path.exists(), "Broken local catalog link: " + href)
catalog = (ROOT / "index.html").read_text()
Links().feed(catalog)
require(fingerprint in catalog and all(item["package"] in catalog for item in records), "The public catalog is stale")
print(json.dumps(dict(passed=True, packages=len(records), signingFingerprint=fingerprint, verifiedSignatures=["InRelease", "Release.gpg"], byHash=True, sourcePackagesMatch=True, catalogLinks=True), indent=2))
