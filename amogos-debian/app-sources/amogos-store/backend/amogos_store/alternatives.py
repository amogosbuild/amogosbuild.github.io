# Source choices are matched to application identities instead of silently swapping package formats.
import concurrent.futures
import difflib
import re
from . import apt_catalog, appimage_catalog, catalog, flatpak_catalog

MATCHES={"vlc":"org.videolan.VLC","steam-installer":"com.valvesoftware.Steam","gimp":"org.gimp.GIMP","firefox-esr":"org.mozilla.firefox","krita":"org.kde.krita","libreoffice-writer":"org.libreoffice.LibreOffice","blender":"org.blender.Blender","inkscape":"org.inkscape.Inkscape","kdenlive":"org.kde.kdenlive","audacity":"org.audacityteam.Audacity","minecraft-pi-reborn":"com.thebrokenrail.MCPIReborn","discord":"com.discordapp.Discord","heroic":"com.heroicgameslauncher.hgl"}


def search_name(text):
    text=re.sub(r"\b(media player|appimage|edition|linux|desktop|launcher)\b","",text.lower())
    return " ".join(text.split())


def normalized(text):
    return re.sub(r"[^a-z0-9]","",search_name(text))


def get(request):
    current=catalog.details(request)
    values=[current];warnings=[]
    known=next((key for key in MATCHES if normalized(key)==normalized(current["name"])),None)
    flat=request["id"] if request["source"]=="flatpak" else MATCHES.get(request["id"]) or MATCHES.get(known)
    deb=request["id"] if request["source"]=="deb" else next((k for k,v in MATCHES.items() if v==request["id"]),known)
    def apt_choices():
        if current.get("aptChoices"):
            return current["aptChoices"]
        identity=deb
        if not identity:
            metadata=apt_catalog.component_metadata()
            identity=next((k for k,v in metadata.items() if v.get("desktopId","").removesuffix(".desktop")==current["id"] or normalized(v.get("name",""))==normalized(current["name"])),None)
        if not identity:
            return []
        return apt_catalog.alternatives(identity)
    def flat_choice():
        if flat:
            return [flatpak_catalog.details(flat)]
        rows,_,_=flatpak_catalog.catalog(current["name"])
        return [v for v in rows if normalized(v["name"])==normalized(current["name"])][:3]
    def image_choices():
        found,_,_=appimage_catalog.catalog(search_name(current["name"]) or current["name"],current=catalog.local_images())
        key=normalized(current["name"])
        matched=[v for v in found if normalized(v["name"])==key or difflib.SequenceMatcher(None,key,normalized(v["name"])).ratio()>.94]
        return sorted(matched,key=lambda v:tuple(int(n) for n in re.findall(r"\d+",v.get("version",""))),reverse=True)[:5]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures=[pool.submit(f) for f in (apt_choices,flat_choice,image_choices)]
        for f in futures:
            try:
                values.extend(f.result())
            except Exception as error:
                warnings.append(str(error))
    unique={}
    for item in values:
        unique[(item["source"],item["id"],item["repo"])]=item
    return dict(items=list(unique.values()),warnings=warnings)
