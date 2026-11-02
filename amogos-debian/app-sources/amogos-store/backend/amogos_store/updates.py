# Update sources fail independently and managed AppImages are compared with their reviewed publisher build.
import concurrent.futures
import re
from . import apt_transactions,appimage_catalog,appimages,flatpak_transactions


def image_updates():
    current=appimages.reconcile()
    values=[]
    warnings=[]
    def check(pair):
        key,entry=pair
        raw=appimage_catalog.raw_details(key)
        builds=appimage_catalog.downloads(raw)
        chosen=next((v for v in builds if v["number"]==entry.get("download")),None)
        if not chosen and entry.get("download") is not None:
            raise ValueError("The installed publisher build is no longer available. Choose a replacement in application details.")
        if not chosen:chosen=builds[0] if builds else None
        if not chosen or not chosen["version"] or chosen["version"]==entry["version"]:return None
        old=re.findall(r"\d+",entry["version"])
        new=re.findall(r"\d+",chosen["version"])
        if old and new and tuple(map(int,new))<=tuple(map(int,old)):return None
        item=appimage_catalog.normalize(raw,current)
        item.update(version=chosen["version"],fromVersion=entry["version"],download=chosen["number"],filename=chosen["name"],size=chosen["size"],updatable=True)
        return item
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        jobs={pool.submit(check,pair):pair[0] for pair in current.items()}
        for job in concurrent.futures.as_completed(jobs):
            try:
                if item:=job.result():values.append(item)
            except Exception as error:
                warnings.append(dict(source="appimage",message=current[jobs[job]]["name"]+": "+str(error)))
    return sorted(values,key=lambda v:v["name"].casefold()),warnings


def get():
    result=dict(system=dict(items=[]),flatpak=[],appimage=[],warnings=[])
    jobs={"system":apt_transactions.updates,"flatpak":flatpak_transactions.updates,"appimage":image_updates}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        tasks={pool.submit(call):key for key,call in jobs.items()}
        for task in concurrent.futures.as_completed(tasks):
            key=tasks[task]
            try:
                value=task.result()
                if key=="appimage":
                    result[key],warnings=value
                    result["warnings"].extend(warnings)
                else:result[key]=value
            except Exception as error:
                result["warnings"].append(dict(source="deb" if key=="system" else key,message=str(error)))
    return result
