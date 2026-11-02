# Authenticate the bundled archive manifest before allowing an installation without downloads.
import hashlib
import json
import pathlib
from .runtime import InstallError

CACHE = "/usr/share/amogos/offline-drivers"


def verified_cache(target):
    directory = pathlib.Path(target) / CACHE.lstrip("/")
    manifest = directory / "manifest.json"
    if not manifest.is_file():
        return None
    try:
        data = json.loads(manifest.read_text())
        if data["schema"] != 1 or not data["packages"]:
            raise ValueError("Invalid manifest")
        archives = (directory / "archives").resolve()
        for item in data["packages"]:
            path = directory / "archives" / item["file"]
            if path.is_symlink() or path.resolve().parent != archives or not path.is_file():
                raise ValueError("Invalid driver archive path")
            with path.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            if digest != item["sha256"] or path.stat().st_size != item["bytes"]:
                raise ValueError("Driver archive verification failed: " + path.name)
        return CACHE + "/archives/"
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise InstallError("The offline driver bundle is incomplete or damaged. " + str(error)) from error
