# User-owned AppImages receive executable launchers and registered menu categories.
import os
import pathlib
import shutil
import subprocess
import tempfile
from .appimage_categories import GROUPS, categories_for
from .network import cached, plain
from .runtime import StoreError

VERSION=2


def cached_categories(key):
    data=cached("https://api.opendesktop.org/ocs/v1/content/data/"+key+"?format=json")
    for item in data.get("data",[]) if isinstance(data,dict) else []:
        if str(item.get("id"))==key:
            return categories_for(item)
    return None


def executable(path):
    if path.is_symlink() or not path.is_file():
        raise StoreError("The installed AppImage file is missing or invalid.")
    if path.stat().st_mode & 0o777!=0o755:
        path.chmod(0o755)
    if not os.access(path,os.X_OK):
        raise StoreError("The AppImage folder does not allow executable files. Use a Linux filesystem that permits running applications.")


def launcher(key, entry, categories):
    allowed={category for group,_,_ in GROUPS for category in group}
    categories=list(dict.fromkeys(value for value in categories if value in allowed)) or ["Utility"]
    directory=pathlib.Path.home()/".local/share/applications"
    directory.mkdir(parents=True,exist_ok=True)
    path=directory/("amogos-appimage-"+key+".desktop")
    title=plain(entry.get("name","Application"))
    title=" ".join(title.split()).replace("\\","\\\\")
    text=("# AppImage integrated by AmogOS App Store.\n[Desktop Entry]\nType=Application\nName="+title+
          "\nExec=/usr/libexec/amogos-appimage-open "+key+
          "\nTryExec=/usr/libexec/amogos-appimage-open\nIcon=application-x-executable\nTerminal=false\nCategories="+
          ";".join(categories)+";\nX-AmogOS-AppImageId="+key+"\n")
    if path.is_symlink() or not path.exists() or path.read_text()!=text:
        fd,temporary=tempfile.mkstemp(prefix=".amogos-launcher-",dir=directory)
        try:
            with os.fdopen(fd,"w") as output:
                output.write(text)
                output.flush()
                os.fsync(output.fileno())
            os.chmod(temporary,0o755)
            pathlib.Path(temporary).replace(path)
        finally:
            pathlib.Path(temporary).unlink(missing_ok=True)
    if path.stat().st_mode & 0o777!=0o755:
        path.chmod(0o755)
    return str(path)


def refresh_menus():
    if os.geteuid()==0:
        return
    commands=[]
    if binary:=shutil.which("update-desktop-database"):
        commands.append([binary,str(pathlib.Path.home()/".local/share/applications")])
    if binary:=shutil.which("kbuildsycoca6") or shutil.which("kbuildsycoca5"):
        commands.append([binary,"--noincremental"])
    for command in commands:
        try:
            subprocess.run(command,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=20,check=False)
        except (OSError,subprocess.TimeoutExpired):
            pass
