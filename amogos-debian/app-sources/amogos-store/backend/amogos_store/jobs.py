# Root-owned journals and independent system services keep reviewed transactions alive across desktop restarts.
import json
import os
import pathlib
import re
import secrets
import sys
import time
import tempfile
import errno
from . import runtime
from .runtime import StoreError

ROOT=pathlib.Path("/var/lib/amogos-store/jobs")
OWNERS=pathlib.Path("/var/lib/amogos-store/owners")
ACTIONS={"apt-apply","flatpak-apply","refresh"}


def identity(value):
    if not isinstance(value,str) or not re.fullmatch(r"[a-f0-9]{48}",value):
        raise StoreError("Invalid background transaction.")
    return value


def unit(key):
    return "amogos-store-"+identity(key)+".service"


def directory(path,mode=0o700,repair_legacy=False):
    path.mkdir(parents=True,exist_ok=True,mode=mode)
    info=path.lstat()
    if path.is_symlink() or info.st_uid!=0:
        raise StoreError("The background transaction directory has unsafe ownership: "+str(path))
    if info.st_mode & 0o022:
        if repair_legacy and info.st_gid==0 and not info.st_mode & 0o002:
            path.chmod(mode)
        else:
            raise StoreError("The background transaction directory has unsafe permissions: "+str(path))
    return path


def readable(path,uid,folder=False):
    if uid:
        runtime.run(["setfacl","-m","u:"+str(uid)+":"+("rx" if folder else "r"),str(path)])


def create_file(path,value,uid=None):
    fd=os.open(path,os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,"w") as output:
        output.write(value)
    if uid is not None:
        readable(path,uid)


def write_state(folder,state):
    try:
        acl=os.getxattr(folder/"state.json","system.posix_acl_access",follow_symlinks=False)
    except OSError as error:
        if error.errno not in (errno.ENODATA,errno.ENOTSUP):
            raise
        acl=None
    fd,name=tempfile.mkstemp(prefix=".state-",dir=folder)
    try:
        with os.fdopen(fd,"w") as output:
            json.dump(state,output)
            output.flush()
        if acl:
            os.setxattr(name,"system.posix_acl_access",acl)
        pathlib.Path(name).replace(folder/"state.json")
    finally:
        pathlib.Path(name).unlink(missing_ok=True)


def load(path):
    try:
        with path.open() as source:
            return json.load(source)
    except (OSError,ValueError):
        return None


def enabled():
    return pathlib.Path("/run/systemd/system").is_dir()


def launch_unit(key):
    args=["systemd-run","--quiet","--collect","--no-ask-password","--unit="+unit(key),"--property=Type=exec","--property=Nice=10","--property=CPUWeight=25","--property=MemoryAccounting=yes","--property=MemoryHigh=256M","--property=OOMPolicy=stop","--property=TimeoutStopSec=600","--setenv=LC_ALL=C.UTF-8","--setenv=DEBIAN_FRONTEND=noninteractive","--setenv=TERM=dumb",sys.executable,"-I",str(pathlib.Path(__file__).resolve().parents[1]/"transaction_worker.py"),key]
    runtime.run(args,timeout=30)


def start(action,request):
    runtime.require_root()
    if action not in ACTIONS or request.get("scope")=="user":
        raise StoreError("Unsupported background transaction.")
    uid=runtime.owner()
    if action=="refresh":
        previous=dict(source="refresh",operation="refresh",id="",summary="Refresh APT indexes")
    else:
        previous=runtime.read_plan(request.get("token"),"deb" if action=="apt-apply" else "flatpak")
    directory(ROOT.parent,0o755,repair_legacy=True)
    directory(ROOT,0o711)
    directory(OWNERS,0o711)
    index=directory(OWNERS/str(uid))
    readable(index,uid,True)
    key=secrets.token_hex(24)
    folder=directory(ROOT/key)
    readable(folder,uid,True)
    now=time.time()
    state=dict(transactionId=key,owner=uid,source=previous["source"],operation=previous["operation"],package=previous.get("id",""),title=previous.get("summary") or previous.get("id") or "Package changes",status="starting",message="Starting a background package transaction",progress=None,startedAt=now,updatedAt=now,done=False)
    create_file(folder/"request.json",json.dumps(dict(action=action,request=request,owner=uid)))
    create_file(folder/"state.json",json.dumps(state),uid)
    create_file(folder/"events.jsonl","",uid)
    create_file(index/(key+".json"),json.dumps(dict(transactionId=key,startedAt=now)),uid)
    try:
        launch_unit(key)
    except Exception as error:
        state.update(status="failed",message=str(error),error=True,updatedAt=time.time())
        write_state(folder,state)
        raise
    runtime.emit("Package changes will continue even if the desktop or Store closes.",transactionId=key)
    follow(key)


def state_for(key):
    state=load(ROOT/identity(key)/"state.json")
    if not state:
        return None
    if state.get("status") in ("starting","running") and time.time()-state.get("updatedAt",0)>5:
        result=runtime.run(["systemctl","show",unit(key),"--property=ActiveState","--value"],timeout=5,check=False)
        if result.returncode or result.stdout.strip() not in ("active","activating","reloading","deactivating"):
            state.update(status="failed",message="The background package operation was interrupted. Open Updates and choose Repair interrupted installation.",error=True,done=False)
    return state


def follow(key):
    last=None
    while True:
        state=state_for(key)
        if state:
            signature=(state.get("updatedAt"),state.get("status"))
            if signature!=last:
                runtime.emit(state.get("message","Applying package changes"),state.get("progress"),transactionId=key,done=state.get("status")=="completed",error=state.get("status")=="failed")
                last=signature
            if state.get("status") in ("failed","completed"):
                return
        time.sleep(.25)


def listing():
    uid=os.getuid()
    folder=OWNERS/str(uid)
    try:
        paths=sorted(folder.glob("*.json"),key=lambda path:path.stat().st_mtime,reverse=True)[:20]
    except OSError:
        return dict(items=[])
    items=[]
    for path in reversed(paths):
        try:
            state=state_for(identity(path.stem))
            if state and state.get("owner")==uid:
                items.append(state)
        except (OSError,StoreError):
            continue
    return dict(items=items)
