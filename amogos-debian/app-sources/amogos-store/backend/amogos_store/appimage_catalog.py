# AppImageHub's shared OCS catalog supplies only application categories and compatible downloads.
import urllib.parse
from .network import fetch, image_url, plain
from .runtime import StoreError
from .appimage_categories import categories_for, in_category

API = "https://api.opendesktop.org/ocs/v1"


def identity(value):
    value=str(value)
    if not value.isdigit() or not 1<=len(value)<=12:
        raise StoreError("Invalid AppImageHub application ID.")
    return value


def categories():
    data=fetch(API+"/content/categories?format=json",age=86400)
    return [c for c in data.get("data",[]) if c.get("xdg_type")=="bin"]


def normalize(item, current=None):
    current=current or {}
    key=str(item["id"])
    local=current.get(key,{})
    return dict(id=key,source="appimage",repo="appimagehub",name=plain(item.get("name",key)),summary=plain(item.get("summary")),description=plain(item.get("description")),icon=image_url(item.get("icon") or item.get("smallpreviewpic1")),screenshots=[image_url(item["previewpic1"])] if item.get("previewpic1") else [],version=str(item.get("version","")),installed=bool(local),installedVersion=local.get("version",""),updatable=bool(local and item.get("version") and str(item["version"])!=local.get("version")),categories=categories_for(item),license=plain(item.get("license","See publisher details")),homepage="https://www.appimagehub.com/p/"+key,developer=plain(item.get("personid","")),size=0)


def catalog(query="",category="",page=0,fresh=False,current=None):
    cats=categories()
    if category:
        cats=[c for c in cats if in_category(c,category)]
    params=dict(format="json",categories=",".join(str(c["id"]) for c in cats),pagesize=24,page=page,sortmode="new" if fresh else "high")
    if query:
        params["search"]=query
    data=fetch(API+"/content/data?"+urllib.parse.urlencode(params))
    values=[normalize(c,current) for c in data.get("data",[]) if c.get("xdg_type")=="bin" and downloads(c)]
    return values,int(data.get("totalitems",0)),bool(data.get("_stale"))


def raw_details(key):
    data=fetch(API+"/content/data/"+identity(key)+"?format=json",age=120)
    rows=data.get("data",[])
    if not rows or rows[0].get("xdg_type")!="bin":
        raise StoreError("This is not an AppImageHub application.")
    return rows[0]


def downloads(item):
    values=[]
    for index in range(1,101):
        s=str(index)
        url=item.get("downloadlink"+s,"")
        name=item.get("downloadname"+s,"")
        kind=item.get("download_package_type"+s,"").lower()
        arch=item.get("download_package_arch"+s,"").lower()
        if not url or (kind!="appimage" and not name.lower().endswith(".appimage")):
            continue
        if arch and arch not in ("x86-64","x86_64","amd64","all","any"):
            continue
        if any(v in name.lower() for v in ("aarch64","arm64","armhf","i386","i686")):
            continue
        values.append(dict(number=index,name=plain(name) or "Application.AppImage",url=url,size=int(item.get("downloadsize"+s) or 0)*1024,md5=item.get("downloadmd5sum"+s,""),version=str(item.get("download_version"+s) or item.get("version","")),architecture=arch or "checked after download"))
    return values


def details(key,current=None):
    raw=raw_details(key)
    item=normalize(raw,current)
    item["downloads"]=[{k:v for k,v in value.items() if k not in ("url","md5")} for value in downloads(raw)]
    return item
