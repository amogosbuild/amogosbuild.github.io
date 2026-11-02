# Reviewed APT transactions are recalculated before applying exact package and version changes.
from . import apt_catalog
from .runtime import StoreError, consume_plan, digest, emit, package_name, save_plan, stream, transaction_lock


def resolve(request):
    c=apt_catalog.cache()
    action=request.get("operation","install")
    if action not in ("install","repair","remove","update","update-selected","upgrade-system"):
        raise StoreError("Unsupported Debian package operation.")
    package=request.get("id","")
    if action=="upgrade-system":
        c.upgrade(dist_upgrade=True)
    elif action=="update-selected":
        selected=request.get("packages")
        if not isinstance(selected,list) or not 1<=len(selected)<=2000:
            raise StoreError("Choose between 1 and 2000 installed packages to update.")
        selected=sorted(set(package_name(value) for value in selected))
        for identity in selected:
            if identity not in c or not c[identity].installed:
                raise StoreError("A selected package is no longer installed: "+identity)
            p=c[identity]
            if not p.candidate or not origins_trusted(p.candidate):
                raise StoreError("A selected update has no trusted repository origin: "+identity)
            p.mark_install(auto_fix=True,auto_inst=True,from_user=False)
    else:
        package_name(package)
        if package not in c:
            raise StoreError("This package is not in your repositories.")
        p=c[package]
        if action=="remove":
            if not p.is_installed:
                raise StoreError("This package is not installed.")
            p.mark_delete(auto_fix=False,purge=False)
        else:
            version=apt_catalog.select_version(p,request.get("repo",""))
            if not version:
                raise StoreError("The selected repository no longer provides this package.")
            if not origins_trusted(version):
                raise StoreError("This package has no trusted repository origin.")
            repo=request.get("repo","")
            if repo and hasattr(c,"_depcache"):
                from .apt_resolution import prefer_family
                prefer_family(c,version,repo)
            p.candidate=version
            p.mark_install(auto_fix=True,auto_inst=True,from_user=True)
            if not p.installed or p.installed.version!=version.version:
                if not p.candidate or p.candidate.version!=version.version or not any(changed.name==p.name for changed in c.get_changes()):
                    raise StoreError("APT could not install the selected repository version with compatible dependencies. Choose another available repository.")
    if c.broken_count:
        raise StoreError("APT could not resolve this transaction. Repair the package state before continuing.")
    changes=[]
    changed=list(c.get_changes())
    if action=="repair" and c[package].installed and not any(p.name==package for p in changed):
        changed.append(c[package])
    for p in changed:
        candidate=p.candidate
        remove=p.marked_delete
        if remove and (p.essential or p.name in PROTECTED):
            raise StoreError("This operation would remove an essential AmogOS system component.")
        if not remove and candidate and not origins_trusted(candidate):
            raise StoreError("A required package is not from a trusted repository.")
        if not remove and p.installed and candidate:
            import apt_pkg
            if apt_pkg.version_compare(candidate.version,p.installed.version)<0:
                raise StoreError("This repository would downgrade an installed package. Choose a newer version or repository.")
        changes.append(dict(id=p.name, action="remove" if remove else "install" if not p.installed else "reinstall" if action=="repair" and p.name==package else "update", fromVersion=p.installed.version if p.installed else "", version="" if remove else candidate.version, size=0 if remove else candidate.size, automatic=bool(p.is_auto_installed)))
    changes.sort(key=lambda x:x["id"])
    installed=[(p.name,p.installed.version) for p in c if p.installed]
    signature=digest(dict(changes=changes,installed=sorted(installed)))
    download=max(c.required_download,sum(v["size"] for v in changes if v["action"]=="reinstall"))
    return dict(source="deb",operation=action,id=package,packages=selected if action=="update-selected" else [],repo=request.get("repo",""),changes=changes,downloadBytes=download,spaceBytes=c.required_space,fingerprint=signature,summary="Update AmogOS 2 Pro" if action=="upgrade-system" else "Update selected APT packages" if action=="update-selected" else action.capitalize()+" "+package,note="The review includes dependencies required by your selected packages." if action=="update-selected" else "")


PROTECTED={"amogos-system","amogos-update","amogos-store","amogos-installer","apt","dpkg","systemd","systemd-sysv","libc6","sudo","polkitd","pkexec","linux-image-amd64","grub-pc-bin","grub-efi-amd64-bin","grub2-common","sddm","plasma-desktop"}


def origins_trusted(version):
    return bool(version and any(o.trusted and o.site for o in version.origins))


def plan(request):
    with transaction_lock():
        return save_plan(resolve(request))


def updates():
    c=apt_catalog.cache()
    items=[dict(id=p.name,name=p.name,source="deb",action="update",fromVersion=p.installed.version,version=p.candidate.version,size=p.candidate.size) for p in c if p.installed and p.candidate and p.is_upgradable]
    items.sort(key=lambda item:item["id"])
    return dict(items=items,downloadBytes=sum(v["size"] for v in items),rebootRequired=reboot_required())


def reboot_required():
    import pathlib
    return pathlib.Path("/var/run/reboot-required").exists()


def apply(request):
    with transaction_lock():
        previous=consume_plan(request.get("token"),"deb")
        current=resolve(previous)
        if current["fingerprint"]!=previous["fingerprint"]:
            raise StoreError("Packages changed after review. Review a fresh transaction.")
        if not current["changes"]:
            emit("Everything is already up to date.",1,done=True)
            return
        emit("Applying the package changes you reviewed.",0)
        packages=[v["id"]+"-" if v["action"]=="remove" else v["id"]+"="+v["version"] for v in current["changes"]]
        if len(packages)>4000:
            raise StoreError("This upgrade is unusually large. Use a terminal package manager.")
        from .runtime import run
        flags=[] if any(v["action"]=="remove" for v in current["changes"]) else ["--no-remove"]
        if any(v["action"]=="reinstall" for v in current["changes"]):
            flags.append("--reinstall")
        stream(["apt-get","-y",*flags,"--install-recommends","-o","Dpkg::Options::=--force-confold","-o","Dpkg::Use-Pty=0","-o","DPkg::Progress-Fancy=0","-o","APT::Status-Fd={status_fd}","install",*packages])
        automatic=[v["id"] for v in current["changes"] if v["action"]!="remove" and v["automatic"]]
        if automatic:
            run(["apt-mark","auto",*automatic])
        run(["apt-get","check"],timeout=180)
        audit=run(["dpkg","--audit"],timeout=180)
        if audit.stdout.strip():
            raise StoreError("Package configuration is unfinished. Repair the package state before continuing. "+audit.stdout[-2000:])
        restart=[v["id"] for v in current["changes"] if v["action"]!="remove" and (v["id"].startswith("linux-image-") or v["id"]=="nvidia-kernel-dkms")]
        if restart:
            import pathlib
            pathlib.Path("/var/run/reboot-required").write_text("Restart required after system updates.\n")
            pathlib.Path("/var/run/reboot-required.pkgs").write_text("\n".join(restart)+"\n")
        emit("System updates installed." if current["operation"]=="upgrade-system" else "Package changes complete.",1,done=True,rebootRequired=reboot_required())


def refresh():
    with transaction_lock():
        emit("Refreshing signed repository indexes.")
        stream(["apt-get","-o","Acquire::Retries=2","-o","APT::Update::Error-Mode=any","update"],timeout=900)
        emit("Repository indexes refreshed.",1,done=True)
