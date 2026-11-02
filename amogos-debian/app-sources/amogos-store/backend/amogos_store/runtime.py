# Fixed commands and owner-bound review tokens isolate privileged package changes.
import contextlib
import fcntl
import hashlib
import json
import os
import pathlib
import re
import secrets
import selectors
import signal
import subprocess
import time


class StoreError(Exception):
    pass


PLAN_DIRECTORY = pathlib.Path("/var/lib/amogos-store/plans")


def run(args, timeout=90, check=True):
    env = dict(os.environ, LC_ALL="C.UTF-8", DEBIAN_FRONTEND="noninteractive")
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout, env=env)
    if check and result.returncode:
        raise StoreError((result.stderr or result.stdout or "The command failed.")[-3000:].strip())
    return result


def emit(message, progress=None, **extra):
    try:
        print(json.dumps(dict(message=message, progress=progress, **extra)), flush=True)
    except BrokenPipeError:
        pass


def stream(args, timeout=3600):
    env = dict(os.environ, LC_ALL="C.UTF-8", DEBIAN_FRONTEND="noninteractive", TERM="dumb",MAKEFLAGS="-j1")
    read_fd,write_fd=os.pipe()
    arguments=[str(value).replace("{status_fd}",str(write_fd)) for value in args]
    try:
        process=subprocess.Popen(arguments,stdout=write_fd,stderr=subprocess.STDOUT,pass_fds=(write_fd,),env=env,start_new_session=True,bufsize=0)
    except BaseException:
        os.close(read_fd)
        raise
    finally:
        os.close(write_fd)
    with process,os.fdopen(read_fd,"rb",buffering=0) as output:
        tail = []
        start = time.monotonic()
        selector=selectors.DefaultSelector()
        selector.register(output,selectors.EVENT_READ)
        pending=b""
        last_emit=0.0
        try:
            while selector.get_map():
                if time.monotonic()-start > timeout:
                    os.killpg(process.pid,signal.SIGTERM)
                    raise StoreError("The package operation exceeded its time limit.")
                for key,_ in selector.select(timeout=1):
                    chunk=os.read(key.fd,8192)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    pending+=chunk.replace(b"\r",b"\n")
                    while b"\n" in pending:
                        line,pending=pending.split(b"\n",1)
                        text=re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]","",line.decode(errors="replace")).strip()
                        if text:
                            tail.append(text[-3000:])
                            tail=tail[-10:]
                            match=re.match(r"(?:pmstatus|dlstatus):[^:]*:([0-9.]+):(.*)",text)
                            progress=min(.99,float(match.group(1))/100) if match else None
                            now=time.monotonic()
                            if now-last_emit>=.25 or "error" in text.lower():
                                emit((match.group(2).strip() if match else text)[-500:],progress)
                                last_emit=now
                    if len(pending)>65536:
                        pending=pending[-65536:]
            if pending.strip():
                emit(pending.decode(errors="replace")[-500:])
        finally:
            selector.close()
        if process.wait():
            raise StoreError("\n".join(tail[-8:]) or "The package operation failed.")


def package_name(value):
    if not isinstance(value, str) or not re.fullmatch(r"[a-z0-9][a-z0-9+.-]*(?::[a-z0-9]+)?", value):
        raise StoreError("Invalid package name.")
    return value


def app_id(value):
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+){2,}", value):
        raise StoreError("Invalid application ID.")
    return value


def user_state():
    if os.geteuid() == 0:
        raise StoreError("User applications must be managed from your desktop account.")
    root = pathlib.Path.home()/".local/share/amogos-store"
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    return root


def owner():
    value = os.environ.get("PKEXEC_UID", str(os.getuid()))
    if not value.isdigit():
        raise StoreError("Invalid authorization identity.")
    return int(value)


def require_root():
    if os.geteuid() != 0:
        raise StoreError("Authenticate through the App Store to change system packages.")


@contextlib.contextmanager
def transaction_lock():
    require_root()
    pathlib.Path("/run/lock").mkdir(exist_ok=True)
    fd = os.open("/run/lock/amogos-store.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise StoreError("Another App Store transaction is already running.")
        yield
    finally:
        os.close(fd)


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def save_plan(plan):
    require_root()
    folder = PLAN_DIRECTORY
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    for old in folder.glob("*.json"):
        if time.time()-old.stat().st_mtime > 3600:
            old.unlink(missing_ok=True)
    token = secrets.token_hex(24)
    path = folder/(token+".json")
    data = dict(plan, owner=owner(), expires=time.time()+900)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as file:
        json.dump(data, file)
    return dict(plan, token=token)


def consume_plan(token, source):
    require_root()
    if not isinstance(token, str) or not re.fullmatch(r"[a-f0-9]{48}", token):
        raise StoreError("Review a new package transaction.")
    path = PLAN_DIRECTORY/(token+".json")
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        raise StoreError("This transaction is no longer available. Review it again.")
    if data["owner"] != owner() or data["expires"] < time.time() or data["source"] != source:
        raise StoreError("This review expired or belongs to another user.")
    path.unlink()
    return data
