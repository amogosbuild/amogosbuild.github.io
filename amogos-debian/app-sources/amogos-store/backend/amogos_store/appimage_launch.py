# AppImage launches retain diagnostics, repair executable mode, and avoid session Qt plugin collisions.
import os
import pathlib
import re
import subprocess
from .appimage_integration import executable
from .runtime import StoreError, user_state
from .session_environment import environment


def start(key, path):
    executable(path)
    with path.open("rb") as source:
        type_two=source.read(11)[8:11]==b"AI\x02"
    folder=user_state()/"logs"
    folder.mkdir(parents=True,exist_ok=True,mode=0o700)
    logpath=folder/("appimage-"+key+"-launch.log")
    env=environment()
    for variable in ("QT_PLUGIN_PATH","QT_QPA_PLATFORM_PLUGIN_PATH","QT_QPA_PLATFORMTHEME","QML2_IMPORT_PATH","QML_IMPORT_PATH"):
        env.pop(variable,None)
    command=[str(path)]
    for attempt in range(2):
        fd=os.open(logpath,os.O_WRONLY|os.O_CREAT|os.O_TRUNC|os.O_NOFOLLOW,0o600)
        with os.fdopen(fd,"wb") as log:
            try:
                process=subprocess.Popen(command,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,cwd=pathlib.Path.home(),env=env)
            except OSError as error:
                raise StoreError("The AppImage could not start: "+str(error)) from error
            try:
                code=process.wait(timeout=2.5)
            except subprocess.TimeoutExpired:
                return dict(launched=True,pid=process.pid,log=str(logpath))
        if code==0:
            return dict(launched=True,log=str(logpath))
        with logpath.open("rb") as log:
            log.seek(max(0,logpath.stat().st_size-6000))
            details=log.read().decode(errors="replace").strip()
        if attempt==0 and type_two and any(word in details.lower() for word in ("fuse","/dev/fuse","error while loading shared libraries")):
            from .appimage_extract import prepare
            command,env=prepare(path,env,logpath)
            continue
        missing=re.search(r"error while loading shared libraries:\s*([^\s:]+)",details)
        explanation=("The publisher's AppImage is missing the required library "+missing.group(1)+". Choose another AppImage build or use the APT/Flatpak version.\n") if missing else ""
        raise StoreError(explanation+"The AppImage exited before opening (code "+str(code)+"). "+(details[-3000:] or "The publisher did not provide an error message.")+"\nLaunch log: "+str(logpath))
