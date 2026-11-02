# Native desktop launches use GIO field-code handling and retain early process errors for the user.
import os
import pathlib
import time
import signal
from .runtime import StoreError, user_state
from .session_environment import environment


def start(identity, desktop):
    from gi.repository import Gio, GLib
    app=Gio.DesktopAppInfo.new_from_filename(str(desktop))
    if app is None:
        raise StoreError("This application's desktop launcher is invalid.")
    env=environment()
    folder=user_state()/"logs"
    folder.mkdir(parents=True,exist_ok=True,mode=0o700)
    logpath=folder/("apt-"+identity.replace(":","_")+"-launch.log")
    context=Gio.AppLaunchContext()
    for key in set(os.environ)-set(env):context.unsetenv(key)
    for key,value in env.items():context.setenv(key,value)
    children=[]
    def spawned(appinfo,pid,data):
        children.append(pid)
    fd=os.open(logpath,os.O_WRONLY|os.O_CREAT|os.O_TRUNC|os.O_NOFOLLOW,0o600)
    null=os.open(os.devnull,os.O_RDONLY)
    try:
        app.launch_uris_as_manager_with_fds([],context,GLib.SpawnFlags.SEARCH_PATH|GLib.SpawnFlags.DO_NOT_REAP_CHILD,None,None,spawned,None,null,fd,fd)
    except GLib.Error as error:
        raise StoreError("The application could not start: "+str(error)) from error
    finally:
        os.close(fd)
        os.close(null)
    deadline=time.monotonic()+3
    statuses=[]
    while time.monotonic()<deadline:
        for pid in children[:]:
            try:waited,status=os.waitpid(pid,os.WNOHANG)
            except ChildProcessError:waited,status=pid,0
            if waited:
                children.remove(pid)
                statuses.append(os.waitstatus_to_exitcode(status))
        time.sleep(.1)
    with logpath.open("rb") as log:
        log.seek(max(0,logpath.stat().st_size-6000))
        details=log.read().decode(errors="replace").strip()
    fatal=any(value in details.lower() for value in ("could not connect to display","cannot open display","no qt platform plugin could be initialized","error while loading shared libraries","no suitable interface module","interface initialization failed"))
    if fatal or (statuses and any(statuses) and not children):
        for pid in children:
            try:os.kill(pid,signal.SIGTERM)
            except ProcessLookupError:pass
        raise StoreError("The application did not open. "+(details[-4000:] or "It exited with code "+str(statuses[-1]))+"\nLaunch log: "+str(logpath))
    return dict(launched=True,log=str(logpath),pids=children)
