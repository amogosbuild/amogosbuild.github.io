# Debian package versions and origins come from the machine's signed APT indexes.
import pathlib
import re
import xml.etree.ElementTree as ET
from .network import plain
from .runtime import StoreError, package_name

PICKS = ["vlc","firefox-esr","gimp","blender","krita","libreoffice-writer","steam-installer","gparted","inkscape","kdenlive","kate","audacity","thunderbird","keepassxc","filezilla","qbittorrent","git","python3","neovim","htop"]
SECTIONS = {"AudioVideo":["sound","video"], "Game":["games"], "Graphics":["graphics"], "Network":["net","web","mail"], "Office":["editors","text"], "Development":["devel","python","interpreters"], "Utility":["utils","admin"], "Education":["education","science","math"]}
APP_IDS = {"vlc":"org.videolan.VLC", "firefox-esr":"org.mozilla.firefox", "gimp":"org.gimp.GIMP", "blender":"org.blender.Blender", "krita":"org.kde.krita", "libreoffice-writer":"org.libreoffice.LibreOffice", "steam-installer":"com.valvesoftware.Steam", "inkscape":"org.inkscape.Inkscape", "kdenlive":"org.kde.kdenlive", "audacity":"org.audacityteam.Audacity"}


def cache():
    try:
        import apt
        import apt_pkg
        apt_pkg.config.set("APT::Install-Recommends", "true")
        apt_pkg.config.set("APT::Install-Suggests", "false")
        return apt.Cache()
    except ImportError as error:
        raise StoreError("The Debian package integration is not installed.") from error


def origin_key(origin):
    return "|".join((origin.site or "local", origin.archive or "", origin.component or ""))


def origins(version):
    return [o for o in version.origins if o.site]


def select_version(package, repo=""):
    if repo=="local":
        return package.installed if package.installed and not origins(package.installed) else None
    versions = list(package.versions) if repo else [package.candidate]
    return next((v for v in versions if v and (not repo or any(origin_key(o)==repo for o in origins(v)))), None)


def repositories(c=None):
    c = c if c is not None else cache()
    result = {}
    if hasattr(c,"_cache"):
        import apt_pkg
        sources=apt_pkg.SourceList()
        sources.read_main_list()
        for file in c._cache.file_list:
            if not file.site or not file.filename.endswith("_Packages"):
                continue
            key=origin_key(file)
            index=sources.find_index(file)
            result[key]=dict(id=key,name=" · ".join(x for x in (file.origin or file.site,file.archive,file.component) if x),site=file.site,trusted=bool(index and index.is_trusted),source="deb",enabled=True)
        return sorted(result.values(),key=lambda x:x["name"])
    for package in c:
        for version in package.versions:
            for o in origins(version):
                key=origin_key(o)
                result[key]=dict(id=key, name=" · ".join(x for x in [o.origin or o.site,o.archive,o.component] if x), site=o.site, trusted=bool(o.trusted), source="deb", enabled=True)
    return sorted(result.values(), key=lambda x:x["name"])


def component_metadata():
    result={}
    for folder in ("/usr/share/metainfo", "/usr/share/appdata"):
        for path in pathlib.Path(folder).glob("*.xml"):
            try:
                if path.stat().st_size>2097152:
                    continue
                component=ET.parse(path).getroot()
                name=component.findtext("pkgname")
                if name:
                    def text(tag):
                        return next((node.text or "" for node in component.findall(tag) if not node.get("{http://www.w3.org/XML/1998/namespace}lang")),"")
                    result[name]=dict(name=text("name") or name,summary=text("summary"),categories=[node.text for node in component.findall("categories/category") if node.text],desktopId=text("id"))
            except (OSError,ET.ParseError):
                continue
    return result


def package_categories(version, metadata):
    section=(version.section or "").split("/")[-1]
    return metadata.get("categories") or [key for key,values in SECTIONS.items() if section in values] or ["Utility"]


def normalize(package, version, metadata=None, include_description=True):
    metadata = metadata or {}
    local = package.installed
    cats=package_categories(version,metadata)
    return dict(id=package.name, source="deb", repo=origin_key(origins(version)[0]) if origins(version) else "local", repositories=[origin_key(o) for o in origins(version)], name=metadata.get("name") or package.name, summary=metadata.get("summary") or version.summary or "", description=plain(version.description) if include_description else "", version=version.version, installed=bool(local), installedVersion=local.version if local else "", updatable=package.is_upgradable, icon="", iconId=APP_IDS.get(package.name,""), screenshots=[], categories=cats, size=version.size or 0, installedSize=version.installed_size or 0, homepage=version.homepage or "", license="See package copyright", desktopId=metadata.get("desktopId",""))


def catalog(query="", repo="", category="", page=0):
    c=cache()
    metadata=component_metadata()
    query=query.casefold().strip()
    rows=[]
    for p in c:
        v=select_version(p,repo)
        if not v:
            continue
        m=metadata.get(p.name.split(":",1)[0],{})
        if query:
            text=" ".join([p.name,v.summary or "",m.get("name",""),m.get("summary","")]).casefold()
            if query not in text and query not in (v.description or "").casefold():
                continue
        if category and category not in package_categories(v,m):
            continue
        name=m.get("name") or p.name
        rank=0 if query and query in (p.name.casefold(),name.casefold()) else 1 if query and (p.name.casefold().startswith(query) or name.casefold().startswith(query)) else 2
        rows.append((rank,PICKS.index(p.name) if p.name in PICKS else len(PICKS),name.casefold(),p.name))
    rows.sort(key=lambda row:row[:4])
    values=[]
    for *_,identity in rows[page*24:(page+1)*24]:
        p=c[identity]
        v=select_version(p,repo)
        m=metadata.get(identity.split(":",1)[0],{})
        item=normalize(p,v,m)
        if repo:
            item["repo"]=repo
        values.append(item)
    return values,len(rows),False


def details(identity,repo=""):
    package_name(identity)
    c=cache()
    if identity not in c or not (version:=select_version(c[identity],repo)):
        raise StoreError("This package is no longer available in the selected repository.")
    metadata=component_metadata().get(identity.split(":",1)[0],{})
    item=normalize(c[identity],version,metadata)
    item["aptChoices"]=alternatives(identity,c=c,metadata=metadata)
    if repo:
        item["repo"]=repo
    return item


def alternatives(identity,c=None,metadata=None):
    package_name(identity)
    c=c if c is not None else cache()
    if identity not in c:
        return []
    p=c[identity]
    metadata=metadata if metadata is not None else component_metadata().get(identity.split(":",1)[0],{})
    values={}
    for version in p.versions:
        for origin in origins(version):
            key=origin_key(origin)
            if key not in values:
                item=normalize(p,version,metadata)
                item["repo"]=key
                values[key]=item
    return list(values.values())
