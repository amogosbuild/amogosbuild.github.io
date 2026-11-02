# User-scoped Flatpak reviews stay in the desktop account and cannot authorize system operations.
import contextlib
import fcntl
import json
import os
import re
import secrets
import time
from .runtime import StoreError, user_state


@contextlib.contextmanager
def lock():
    fd=os.open(user_state()/".flatpak.lock",os.O_RDWR|os.O_CREAT|os.O_NOFOLLOW,0o600)
    try:
        fcntl.flock(fd,fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def save(plan):
    folder=user_state()/"flatpak-plans"
    folder.mkdir(exist_ok=True,mode=0o700)
    for path in folder.glob("*.json"):
        if time.time()-path.stat().st_mtime>3600:
            path.unlink(missing_ok=True)
    token=secrets.token_hex(24)
    fd=os.open(folder/(token+".json"),os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,"w") as output:
        json.dump(dict(plan,expires=time.time()+900,owner=os.getuid()),output)
    return dict(plan,token=token)


def consume(token):
    if not isinstance(token,str) or not re.fullmatch(r"[a-f0-9]{48}",token):
        raise StoreError("Review the user Flatpak transaction again.")
    path=user_state()/"flatpak-plans"/(token+".json")
    try:
        data=json.loads(path.read_text())
    except (OSError,ValueError) as error:
        raise StoreError("This Flatpak review is no longer available.") from error
    if data.get("scope")!="user" or data.get("owner")!=os.getuid() or data.get("expires",0)<time.time():
        raise StoreError("This user Flatpak review expired.")
    path.unlink()
    return data
