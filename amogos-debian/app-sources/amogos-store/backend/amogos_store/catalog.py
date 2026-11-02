# Independent catalogs fail separately so one unavailable source does not hide the others.
import concurrent.futures
import os
import pathlib
import pwd
import subprocess
import shutil
from . import apt_catalog, appimage_catalog, appimages, flatpak_catalog, flatpak_transactions, flatpak_local
from .runtime import StoreError, app_id, package_name, run


def local_images():
    return appimages.reconcile() if os.geteuid()!=0 else {}


def search(request):
    source=request.get("source","all")
    query=str(request.get("query",""))[:160].strip()
    category=str(request.get("category",""))[:80]
    page=request.get("page",0)
    if type(page) is not int or not 0<=page<=1000000:
        raise StoreError("Invalid catalog page.")
    jobs={}
    if source in ("all","deb") and not (request.get("fresh") and source=="all"):
        jobs["deb"]=lambda:apt_catalog.catalog(query,str(request.get("repo","")),category,page)
    if source in ("all","flatpak"):
        jobs["flatpak"]=lambda:flatpak_catalog.catalog(query,category,page,bool(request.get("fresh")))
    if source in ("all","appimage"):
        jobs["appimage"]=lambda:appimage_catalog.catalog(query,category,page,bool(request.get("fresh")),local_images())
    if not jobs:
        raise StoreError("Choose a supported package source.")
    items=[];warnings=[];totals={}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        tasks={pool.submit(call):name for name,call in jobs.items()}
        for future in concurrent.futures.as_completed(tasks):
            name=tasks[future]
            try:
                values,total,stale=future.result()
                items.extend(values);totals[name]=total
                if stale:
                    warnings.append(dict(source=name,message="Showing cached catalog data; the source is currently offline."))
            except Exception as error:
                warnings.append(dict(source=name,message=str(error)))
    items.sort(key=lambda x:(0 if query and (x["id"].lower()==query.lower() or x["name"].lower()==query.lower()) else 1 if query and x["name"].lower().startswith(query.lower()) else 2,0 if x["source"]=="deb" else 1 if x["source"]=="flatpak" else 2))
    return dict(items=items,warnings=warnings,totals=totals,page=page)


def details(request):
    source=request.get("source")
    if source=="deb":
        return apt_catalog.details(request.get("id"),request.get("repo",""))
    if source=="flatpak":
        return flatpak_catalog.details(request.get("id"),request.get("scope","system"),request.get("reference",""))
    if source=="appimage":
        item=appimage_catalog.details(request.get("id"),local_images())
        if item["installed"]:
            appimages.reconcile({item["id"]:item["categories"]})
        return item
    raise StoreError("Choose a supported package source.")


def sources():
    account=pwd.getpwuid(os.getuid())
    name=account.pw_gecos.split(",")[0] or account.pw_name
    warnings=[]
    try:
        repositories=apt_catalog.repositories()
    except Exception as error:
        repositories=[];warnings.append(str(error))
    return dict(name=name,repositories=repositories,flatpak=flatpak_transactions.remotes(),flatpakInstalled=bool(shutil.which("flatpak")),appimage=dict(id="appimagehub",name="AppImageHub",enabled=True,url="https://www.appimagehub.com"),warnings=warnings)


def launch(request):
    source=request.get("source")
    if os.geteuid()==0:
        raise StoreError("Launch applications from your desktop account.")
    if source=="appimage":
        return appimages.launch(request.get("id"))
    if source=="flatpak":
        identity=app_id(request.get("id"))
        scope=flatpak_local.scope(request.get("scope","system"))
        current=next((v for v in flatpak_local.listing(scope) if v["id"]==identity and not v["runtime"] and (not request.get("reference") or v["reference"]==request["reference"])),None)
        if current is None:
            raise StoreError("This Flatpak is not installed.")
        args=["flatpak","--"+scope,"run",current["reference"]]
    elif source=="deb":
        identity=package_name(request.get("id"))
        status=run(["dpkg-query","-W","-f="+chr(36)+"{db:Status-Status}",identity],check=False)
        if status.returncode or status.stdout.strip()!="installed":
            raise StoreError("This package is not installed.")
        files=run(["dpkg-query","-L",identity]).stdout.splitlines()
        desktops=[pathlib.Path(p) for p in files if p.startswith("/usr/share/applications/") and p.endswith(".desktop") and pathlib.Path(p).is_file()]
        desktops.sort(key=lambda p:("NoDisplay=true" in p.read_text(),p.name!=identity+".desktop",p.name))
        desktop=next(iter(desktops),None)
        if not desktop:
            raise StoreError("This package has no desktop launcher. It may be a command-line tool.")
        from . import desktop_launch
        return desktop_launch.start(identity,desktop)
    else:
        raise StoreError("Unsupported application source.")
    subprocess.Popen(args,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
    return dict(launched=True)


def open_link(request):
    from urllib.parse import urlsplit
    url=str(request.get("url",""))
    parsed=urlsplit(url)
    if os.geteuid()==0 or parsed.scheme!="https" or not parsed.hostname or parsed.username or parsed.password:
        raise StoreError("Open public website links from your desktop account.")
    subprocess.Popen(["gio","open",url],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
    return dict(opened=True)
