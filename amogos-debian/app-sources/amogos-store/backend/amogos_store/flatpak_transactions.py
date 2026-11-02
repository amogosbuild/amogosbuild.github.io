# Flatpak reviews preserve installation scope, configured origin, reference, and exact commit.
import os
import re
import shutil
from . import flatpak_local, user_plans
from .runtime import StoreError, app_id, consume_plan, emit, run, save_plan, stream, transaction_lock


def remotes(scope="system"):
    flatpak_local.scope(scope)
    if not shutil.which("flatpak"):
        return []
    result=run(["flatpak","--"+scope,"remotes","--columns=name,url,options"],check=False)
    return [dict(id=v[0],source="flatpak",name=v[0],url=v[1],scope=scope,enabled="disabled" not in v[-1]) for line in result.stdout.splitlines() if len(v:=line.split("\t"))>=2]


def check_remote(scope="system",origin="flathub",official=True):
    if not shutil.which("flatpak"):
        raise StoreError("Flatpak needs to be installed before you can install Flatpak apps. Install Flatpak from APT in Sources.")
    remote=next((r for r in remotes(scope) if r["id"]==origin),None)
    if not remote or not remote["enabled"]:
        raise StoreError("Enable "+origin+" in the "+scope+" Flatpak installation before continuing.")
    if official and remote["url"].rstrip("/") not in ("https://dl.flathub.org/repo","https://flathub.org/repo"):
        raise StoreError("The flathub remote does not point to the official repository.")
    return remote


def resolve(request):
    scope=flatpak_local.scope(request.get("scope","system"))
    if scope=="user" and os.geteuid()==0:
        raise StoreError("User Flatpaks must be managed from the desktop account.")
    operation=request.get("operation","install")
    if operation=="update-selected":
        packages=request.get("packages")
        if not isinstance(packages,list) or not 1<=len(packages)<=200:
            raise StoreError("Choose between 1 and 200 Flatpak updates.")
        if any(not isinstance(p,dict) for p in packages):
            raise StoreError("Choose installed Flatpak references.")
        items=[resolve(dict(p,scope=scope,operation="update")) for p in packages]
        if len({p["reference"] for p in items})!=len(items):
            raise StoreError("A Flatpak update was selected more than once.")
        return dict(source="flatpak",id="",operation=operation,scope=scope,packages=packages,items=items,commits={p["reference"]:p["commit"] for p in items},changes=[v for p in items for v in p["changes"]],summary="Update selected "+scope+" Flatpaks",downloadBytes=0,note="Only selected references are requested. Required Flatpak runtime dependencies may also be installed or updated.")
    identity=app_id(request.get("id",""))
    if operation not in ("install","update","remove"):
        raise StoreError("Unsupported Flatpak operation.")
    local=flatpak_local.listing(scope)
    reference=request.get("reference","")
    current=next((v for v in local if v["id"]==identity and (not reference or v["reference"]==reference)),None)
    if operation in ("remove","update") and not current:
        raise StoreError("This Flatpak reference is not installed in the selected installation.")
    origin=current["origin"] if current else "flathub"
    remote=(next((r for r in remotes(scope) if r["id"]==origin),None) or dict(url="")) if operation=="remove" else check_remote(scope,origin,official=operation=="install")
    selected=current["reference"] if current else identity
    if operation=="remove":
        commit=run(["flatpak","--"+scope,"info","--show-commit",selected]).stdout.strip()
        reference=selected
    else:
        commit=run(["flatpak","--"+scope,"remote-info","--show-commit",origin,selected]).stdout.strip()
        reference=run(["flatpak","--"+scope,"remote-info","--show-ref",origin,selected]).stdout.strip()
    if not re.fullmatch(r"[a-f0-9]{64}",commit) or not re.fullmatch(r"(?:app|runtime)/"+re.escape(identity)+r"/(?:x86_64|i386)/[A-Za-z0-9._-]+",reference):
        raise StoreError("The remote returned an unsupported Flatpak reference.")
    return dict(source="flatpak",id=identity,scope=scope,origin=origin,remoteUrl=remote["url"],operation=operation,commit=commit,reference=reference,summary=operation.capitalize()+" "+identity,changes=[dict(id=reference,action=operation,version=commit[:12])],downloadBytes=0,spaceBytes=0,note=scope.capitalize()+" Flatpak installation · "+origin+". Required runtimes may also change. Application data is kept on removal.")


def plan(request):
    user=request.get("scope","system")=="user"
    with user_plans.lock() if user else transaction_lock():
        value=resolve(request)
        return user_plans.save(value) if user else save_plan(value)


def apply(request):
    user=request.get("scope","system")=="user"
    with user_plans.lock() if user else transaction_lock():
        previous=user_plans.consume(request.get("token")) if user else consume_plan(request.get("token"),"flatpak")
        current=resolve(previous)
        fields=("commits","scope","items") if current["operation"]=="update-selected" else ("commit","reference","scope","origin","remoteUrl")
        if any(current[k]!=previous.get(k) for k in fields):
            raise StoreError("The Flatpak changed after review. Review it again.")
        emit("Applying the reviewed Flatpak change.")
        for item in current.get("items",[current]):
            operation=item["operation"]
            args=["flatpak","--"+item["scope"],"uninstall" if operation=="remove" else operation,"--noninteractive","-y"]
            if operation=="install":args.append(item["origin"])
            if operation=="update":args.append("--commit="+item["commit"])
            args.append(item["reference"])
            stream(args)
        emit("Flatpak change complete.",1,done=True)


def updates():
    return flatpak_local.updates()


def configure(enabled):
    with transaction_lock():
        if not shutil.which("flatpak"):
            raise StoreError("Flatpak needs to be installed first. Use Install Flatpak in Sources.")
        if not isinstance(enabled,bool):
            raise StoreError("Choose whether Flathub is enabled.")
        if not any(r["id"]=="flathub" for r in remotes()):
            if not enabled:return dict(enabled=False)
            run(["flatpak","--system","remote-add","--if-not-exists","flathub","https://dl.flathub.org/repo/flathub.flatpakrepo"],timeout=180)
        else:
            remote=next(r for r in remotes() if r["id"]=="flathub")
            if remote["url"].rstrip("/") not in ("https://dl.flathub.org/repo","https://flathub.org/repo"):
                raise StoreError("An existing remote named flathub uses a different URL.")
            run(["flatpak","--system","remote-modify","--enable" if enabled else "--disable","flathub"])
        return dict(enabled=enabled)
