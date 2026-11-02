# Installed Flatpak references retain their installation scope, branch, origin, and runtime identity.
import shutil
from .runtime import StoreError, run


def scope(value):
    if value not in ("system","user"):
        raise StoreError("Choose a system or user Flatpak installation.")
    return value


def listing(installation="system"):
    scope(installation)
    if not shutil.which("flatpak"):
        return []
    rows=[]
    for kind in ("app","runtime"):
        result=run(["flatpak","--"+installation,"list","--"+kind,"--columns=application,name,version,branch,origin,ref"])
        for line in result.stdout.splitlines():
            fields=line.split("\t")
            if len(fields)<6 or not fields[0]:
                continue
            identity,name,version,branch,origin,reference=fields[:6]
            reference=reference if reference.startswith(("app/","runtime/")) else kind+"/"+reference
            rows.append(dict(id=identity,name=name or identity,version=version,installedVersion=version,branch=branch,origin=origin,repo=origin,reference=reference,scope=installation,runtime=kind=="runtime",source="flatpak",installed=True,summary=("Runtime" if kind=="runtime" else "Application")+" · "+installation+" installation",description="Installed from "+origin+" for the "+installation+" installation.",categories=["Utility"],size=0))

    return rows


def updates():
    if not shutil.which("flatpak"):
        return []
    values=[]
    for installation in ("system","user"):
        local={row["reference"].split("/",1)[1]:row for row in listing(installation)}
        result=run(["flatpak","--"+installation,"remote-ls","--updates","--columns=application,name,version,ref"])
        for line in result.stdout.splitlines():
            fields=line.split("\t")
            if len(fields)>=4 and fields[3] in local:
                row=dict(local[fields[3]],fromVersion=local[fields[3]]["version"],version=fields[2],updatable=True)
                values.append(row)
    return values
