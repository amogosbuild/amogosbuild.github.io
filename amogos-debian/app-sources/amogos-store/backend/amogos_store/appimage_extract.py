# Reuse a bounded-memory extracted AppDir when FUSE or a publisher's library search path prevents launching.
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
from .runtime import StoreError


def prepare(path, env, logpath):
    info=path.stat()
    signature=json.dumps([info.st_ino,info.st_size,info.st_mtime_ns])
    destination=path.parent/"extracted"
    marker=destination/".amogos-extracted"
    current=not destination.is_symlink() and marker.is_file() and marker.read_text()==signature
    if not current:
        with tempfile.TemporaryDirectory(prefix=".extract-",dir=path.parent) as temporary:
            with logpath.open("ab") as log:
                try:
                    result=subprocess.run([str(path),"--appimage-extract"],cwd=temporary,env=env,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=log,timeout=180)
                except subprocess.TimeoutExpired as error:
                    raise StoreError("AppImage extraction timed out. Launch log: "+str(logpath)) from error
            extracted=pathlib.Path(temporary)/"squashfs-root"
            if result.returncode or not (extracted/"AppRun").is_file():
                raise StoreError("The AppImage could not be extracted for launching. Launch log: "+str(logpath))
            if destination.is_symlink():
                destination.unlink()
            elif destination.exists():
                shutil.rmtree(destination)
            extracted.replace(destination)
            marker.write_text(signature)
    appdir_env=dict(env,APPDIR=str(destination),APPIMAGE=str(path),OWD=str(pathlib.Path.home()))
    libraries=[destination/p for p in ("usr/lib/x86_64-linux-gnu","usr/lib64","usr/lib","lib/x86_64-linux-gnu","lib64","lib")]
    appdir_env["LD_LIBRARY_PATH"]=":".join([str(p) for p in libraries if p.is_dir()]+([env["LD_LIBRARY_PATH"]] if env.get("LD_LIBRARY_PATH") else []))
    return [str(destination/"AppRun")],appdir_env
