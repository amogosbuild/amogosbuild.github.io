# AppImages are validated and integrated only in the current user's application directory.
import hashlib
import contextlib
import fcntl
import json
import os
import pathlib
import re
import struct
import tempfile
import time
import shutil
from . import appimage_catalog, appimage_integration, appimage_launch
from .network import open_url
from .runtime import StoreError, emit, user_state


def manifest():
    path=user_state()/"appimages.json"
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return {}


def save(values):
    root=user_state()
    fd,path=tempfile.mkstemp(prefix=".manifest-",dir=root)
    with os.fdopen(fd,"w") as file:
        json.dump(values,file)
    pathlib.Path(path).replace(root/"appimages.json")


@contextlib.contextmanager
def manifest_lock():
    fd=os.open(user_state()/".appimages.lock",os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
    try:
        fcntl.flock(fd,fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def validate_header(header):
    if len(header)<64 or header[:4]!=b"\x7fELF" or header[8:11] not in (b"AI\x01",b"AI\x02"):
        raise StoreError("The downloaded file is not a supported AppImage.")
    if header[4]!=2 or header[5]!=1 or struct.unpack_from("<H",header,18)[0]!=62:
        raise StoreError("This AppImage is not for the ISO's x86-64 architecture.")


def quoted(value):
    return '"'+str(value).replace("\\","\\\\").replace('"','\\"').replace(chr(96),"\\"+chr(96)).replace("$","\\$").replace("%","%%")+'"'


def install(request):
    root=user_state()
    key=appimage_catalog.identity(request.get("id",""))
    raw=appimage_catalog.raw_details(key)
    selected=next((x for x in appimage_catalog.downloads(raw) if x["number"]==request.get("download")),None)
    if not selected:
        raise StoreError("Choose an available x86-64 AppImage download.")
    if request.get("version") and selected["version"]!=str(request["version"]):
        raise StoreError("This download changed after review. Open its details again.")
    folder=root/"appimages"/key
    folder.mkdir(parents=True,exist_ok=True,mode=0o700)
    destination=folder/"application.AppImage"
    fd,temporary=tempfile.mkstemp(prefix=".download-",dir=folder)
    sha=hashlib.sha256();md5=hashlib.md5();count=0;last=0
    try:
        emit("Downloading "+selected["name"],0)
        with os.fdopen(fd,"wb") as file,open_url(selected["url"],timeout=120) as response:
            total=int(response.headers.get("Content-Length","0") or 0)
            if total>3*1024**3:
                raise StoreError("This AppImage exceeds the 3 GiB download limit.")
            while chunk:=response.read(262144):
                count+=len(chunk)
                if count>3*1024**3:
                    raise StoreError("This AppImage exceeds the 3 GiB download limit.")
                file.write(chunk);sha.update(chunk);md5.update(chunk)
                if time.monotonic()-last>.3:
                    emit("Downloading "+selected["name"],min(.94,count/total*.94) if total else None,downloadedBytes=count,totalBytes=total)
                    last=time.monotonic()
            file.flush();os.fsync(file.fileno())
        path=pathlib.Path(temporary)
        with path.open("rb") as file:
            validate_header(file.read(64))
        checksum=selected["md5"]
        if checksum and re.fullmatch(r"[a-fA-F0-9]{32}",checksum) and md5.hexdigest().lower()!=checksum.lower():
            raise StoreError("The download does not match AppImageHub's published checksum.")
        path.chmod(0o755)
        path.replace(destination)
        appimage_integration.executable(destination)
        title=str(raw.get("name","Application"))
        categories=appimage_catalog.categories_for(raw)
        entry=dict(path=str(destination),name=title,version=selected["version"],download=selected["number"],sha256=sha.hexdigest(),source="appimagehub",installedAt=time.time(),categories=categories,integrationVersion=appimage_integration.VERSION)
        entry["desktop"]=appimage_integration.launcher(key,entry,categories)
        with manifest_lock():
            values=manifest()
            values[key]=entry
            save(values)
        appimage_integration.refresh_menus()
        emit(title+" is ready in your application menu.",1,done=True)
    finally:
        pathlib.Path(temporary).unlink(missing_ok=True)


def owned(key):
    key=appimage_catalog.identity(key)
    values=manifest()
    if key not in values:
        raise StoreError("This AppImage is not installed through the App Store.")
    expected=user_state()/"appimages"/key/"application.AppImage"
    if pathlib.Path(values[key]["path"])!=expected or expected.is_symlink():
        raise StoreError("The stored AppImage path is invalid.")
    return key,values,expected


def reconcile(overrides=None):
    changed=False
    with manifest_lock():
        values=manifest()
        for key,entry in values.items():
            try:
                appimage_catalog.identity(key)
                expected=user_state()/"appimages"/key/"application.AppImage"
                if pathlib.Path(entry["path"])!=expected:
                    continue
                appimage_integration.executable(expected)
                categories=(overrides or {}).get(key) or appimage_integration.cached_categories(key) or entry.get("categories") or ["Utility"]
                before=dict(entry)
                entry["desktop"]=appimage_integration.launcher(key,entry,categories)
                entry.update(categories=categories,integrationVersion=appimage_integration.VERSION)
                changed|=entry!=before
            except (OSError,ValueError,StoreError):
                continue
        if changed:
            save(values)
    if changed:
        appimage_integration.refresh_menus()
    return values


def remove(key):
    with manifest_lock():
        key,values,path=owned(key)
        path.unlink(missing_ok=True)
        extracted=path.parent/"extracted"
        if extracted.is_symlink():
            extracted.unlink()
        elif extracted.exists():
            shutil.rmtree(extracted)
        (pathlib.Path.home()/".local/share/applications"/("amogos-appimage-"+key+".desktop")).unlink(missing_ok=True)
        del values[key]
        save(values)
    appimage_integration.refresh_menus()
    emit("AppImage removed. Your application data was kept.",1,done=True)


def launch(key):
    key,values,path=owned(key)
    from .appimage_compatibility import BROKEN_SHA256, MESSAGE
    if values[key].get("sha256") in BROKEN_SHA256:
        raise StoreError(MESSAGE+" Open this app's details and choose the compatible AppImage.")
    if not path.is_file():
        raise StoreError("The installed AppImage file is missing.")
    reconcile()
    return appimage_launch.start(key,path)
