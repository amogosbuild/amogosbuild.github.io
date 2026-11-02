# Flathub supplies live application metadata while Flatpak reports installed system applications.
import shutil
from .network import fetch, image_url, plain
from .runtime import app_id, StoreError
from . import flatpak_local

API = "https://flathub.org/api/v2"
CATEGORIES = {"AudioVideo":"audiovideo", "Game":"game", "Graphics":"graphics", "Network":"network", "Office":"office", "Development":"development", "Utility":"utility", "Education":"education"}


def installed(scope="system"):
    return {v["id"]:v for v in flatpak_local.listing(scope) if not v["runtime"]}


def current_apps():
    values=installed()
    for key,value in installed("user").items():
        values.setdefault(key,value)
    return values


def normalize(item, current):
    identity = item.get("app_id") or item.get("id", "")
    screenshots = [image_url(size["src"]) for image in item.get("screenshots", []) for size in image.get("sizes", []) if size.get("width") in ("752","1280")]
    releases = item.get("releases") or []
    local = current.get(identity, {})
    version = releases[0].get("version", "") if releases else item.get("version", "")
    return dict(id=identity, source="flatpak", repo=local.get("origin","flathub"),scope=local.get("scope","system"),reference=local.get("reference",""), name=item.get("name", identity), summary=plain(item.get("summary")), description=plain(item.get("description")), icon=image_url(item.get("icon")), screenshots=screenshots[:4], version=version, installed=bool(local), installedVersion=local.get("version",""), updatable=bool(local and version and local.get("version")!=version), categories=item.get("categories", [str(item.get("main_categories",""))]), license=item.get("project_license", ""), homepage=(item.get("urls") or {}).get("homepage",""), developer=item.get("developer_name",""), verified=bool(item.get("verification_verified")), size=0)


def catalog(query="", category="", page=0, fresh=False):
    body = dict(query=query, page=page+1, hits_per_page=24)
    if category in CATEGORIES:
        body["filters"] = [dict(filterType="main_categories", value=CATEGORIES[category])]
    if fresh and not query and not category:
        data = fetch(API+"/collection/recently-added", age=900)
        data = dict(data, totalHits=data.get("totalHits") or len(data.get("hits",[])), hits=data.get("hits",[])[page*24:(page+1)*24])
    else:
        data = fetch(API+"/search", body)
    current = current_apps()
    return [normalize(item, current) for item in data.get("hits", [])], data.get("totalHits",0), bool(data.get("_stale"))


def details(identity,scope="system",reference=""):
    app_id(identity)
    local=next((v for v in flatpak_local.listing(scope) if v["id"]==identity and (not reference or v["reference"]==reference)),None)
    if local and (local["runtime"] or local["origin"]!="flathub"):
        return local
    try:
        return normalize(fetch(API+"/appstream/"+identity),{identity:local} if local else {})
    except StoreError:
        if local:return local
        raise
