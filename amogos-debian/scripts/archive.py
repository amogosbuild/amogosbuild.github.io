# Shared package construction and metadata helpers keep repository builds independent of user data.
import email.parser
import hashlib
import io
import os
import pathlib
import re
import shutil
import subprocess
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PACKAGE_PATTERN = re.compile(r"[a-z0-9][a-z0-9+.-]+")
VERSION_PATTERN = re.compile(r"[0-9][A-Za-z0-9.+~_-]*")


def run(arguments, **kwargs):
    return subprocess.check_output([str(a) for a in arguments], **kwargs)


def fields(text):
    return dict(email.parser.Parser().parsestr(text).items())


def sha256(path):
    with pathlib.Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def package_info(path):
    return fields(run(["dpkg-deb", "--field", path], text=True))


def write(path, value, mode=0o644):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(value, bytes):
        path.write_bytes(value)
    else:
        path.write_text(value, encoding="utf-8", newline="\n")
    path.chmod(mode)


def build_package(source, destination, public_key=None, version=None, payload=None):
    source, destination = pathlib.Path(source), pathlib.Path(destination)
    control = (source / "control").read_text()
    if version is not None:
        control = re.sub(r"(?m)^Version: .+$", "Version: " + version, control)
    info = fields(control)
    name, version = info["Package"], info["Version"]
    if not PACKAGE_PATTERN.fullmatch(name) or not VERSION_PATTERN.fullmatch(version):
        raise ValueError("Invalid package identity or version")
    destination.mkdir(parents=True, exist_ok=True)
    result = destination / (name + "_" + version + "_all.deb")
    with tempfile.TemporaryDirectory(prefix="amogos-package-") as temporary:
        stage = pathlib.Path(temporary)
        if name == "amogos-update":
            write(stage / "usr/bin/amogos-update", payload if payload is not None else (source / "amogos-update").read_text(), 0o755)
            for script in ("postinst", "postrm"):
                write(stage / "DEBIAN" / script, (source / script).read_text().replace("@VERSION@", version), 0o755)
        elif name == "amogos-system":
            write(stage / "DEBIAN/postinst", (source / "postinst").read_text(), 0o755)
        elif name == "amogos-archive-keyring":
            if not public_key:
                raise ValueError("A public archive key is required")
            write(stage / "usr/share/keyrings/amogos-archive-keyring.gpg", public_key)
            write(stage / "etc/apt/sources.list.d/amogos.sources", (source / "amogos.sources").read_text())
            write(stage / "DEBIAN/conffiles", "/etc/apt/sources.list.d/amogos.sources\n")
        else:
            raise ValueError("Unknown maintained package: " + name)
        resources=source/"rootfs"
        if resources.is_dir():
            shutil.copytree(resources,stage,dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__','*.pyc','*.pyo'))
            for path in stage.rglob("*"):
                if path.relative_to(stage).parts[0] != "DEBIAN":
                    if path.is_dir():
                        path.chmod(0o755)
                    elif (resources/path.relative_to(stage)).is_file():
                        path.chmod(0o644)
            executable=(stage/"usr/libexec/amogos-installed-cleanup")
            if executable.exists():
                executable.chmod(0o755)
            configuration=["/"+str(path.relative_to(stage)).replace(os.sep,"/") for path in (stage/"etc").rglob("*") if path.is_file()] if (stage/"etc").exists() else []
            if configuration:
                write(stage/"DEBIAN/conffiles","\n".join(sorted(configuration))+"\n")
        payload_paths = [p for p in stage.rglob("*") if p.relative_to(stage).parts[0] != "DEBIAN"]
        stage.chmod(0o755)
        size = sum(4 if p.is_dir() else (p.stat().st_size + 1023) // 1024 for p in payload_paths)
        write(stage / "DEBIAN/control", control.rstrip() + "\nInstalled-Size: " + str(size) + "\n")
        environment = dict(os.environ, SOURCE_DATE_EPOCH=os.environ.get("SOURCE_DATE_EPOCH", "1793491200"))
        subprocess.run(["dpkg-deb", "--root-owner-group", "--build", str(stage), str(result)], env=environment, check=True, stdout=subprocess.DEVNULL)
    return result


def package_contents(path):
    result = {}
    for flag, prefix in (("--ctrl-tarfile", "control"), ("--fsys-tarfile", "data")):
        with tarfile.open(fileobj=io.BytesIO(run(["dpkg-deb", flag, path]))) as archive:
            for item in archive:
                if item.isdir():
                    continue
                content = archive.extractfile(item).read() if item.isfile() else item.linkname.encode()
                result[(prefix, item.name)] = (item.mode, item.type, hashlib.sha256(content).hexdigest())
    return result


def place_package(package, root=ROOT):
    info = package_info(package)
    name = info["Package"]
    if not PACKAGE_PATTERN.fullmatch(name):
        raise ValueError("Invalid package name")
    destination = root / "pool/main" / name[0] / name / pathlib.Path(package).name
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if package_contents(destination) != package_contents(package):
            raise ValueError("Package contents changed without a version bump: " + destination.name)
    else:
        shutil.copyfile(package, destination)
        destination.chmod(0o644)
    return destination
