# Online installs refresh every repository, perform a full upgrade, and verify the final package state.
import datetime
import json
import pathlib
import re
import subprocess
import tempfile
from .drivers import install_drivers
from .runtime import InstallError
from .storage import online

NETWORK_OPTIONS = ["-o", "Acquire::Retries=3", "-o", "Acquire::http::Timeout=20", "-o", "Acquire::https::Timeout=20", "-o", "APT::Update::Error-Mode=any"]
INSTALL_OPTIONS = ["-o", "Dpkg::Options::=--force-confold", "-o", "Dpkg::Use-Pty=0", "-o", "DPkg::Progress-Fancy=0", "-o", "APT::Status-Fd={status_fd}"]
STATE_SCRIPT = """
import apt,apt_pkg,json
c=apt.Cache()
installed={p.fullname:p.installed.version for p in c if p.installed}
pending=[dict(id=p.fullname,installed=p.installed.version,candidate=p.candidate.version) for p in c if p.installed and p.candidate and apt_pkg.version_compare(p.candidate.version,p.installed.version)>0]
broken=[p.fullname for p in c if p.is_inst_broken]
protected={"apt","dpkg","libc6","systemd","systemd-sysv","linux-image-amd64","plasma-desktop","sddm","network-manager","wpasupplicant","amogos-installer","amogos-store","amogos-music","steam-installer"}
c.upgrade(dist_upgrade=True)
removals=[p.fullname for p in c.get_changes() if p.marked_delete]
blocked=[p.fullname for p in c.get_changes() if p.marked_delete and (p.essential or p.name.split(":")[0] in protected)]
print(json.dumps(dict(installed=installed,pending=pending,broken=broken,removals=removals,protectedRemovals=blocked)))
"""


def refresh(runner, target=None, options=()):
    prefix=["chroot",str(target)] if target is not None else []
    try:
        runner.run(prefix+["apt-get",*NETWORK_OPTIONS,*options,"update"],timeout=600)
    except subprocess.TimeoutExpired as error:
        raise InstallError("Repository refresh timed out. Reconnect to the internet before choosing an online installation.") from error


def prepare_online(runner, report):
    report.emit("prepare",.03,"Checking online repositories before changing drives")
    try:
        with tempfile.TemporaryDirectory(prefix="amogos-repository-check-",dir="/var/tmp") as temporary:
            directory=pathlib.Path(temporary)
            directory.chmod(0o755)
            (directory/"lists").mkdir()
            refresh(runner,options=["-o","Dir::State::lists="+str(directory/"lists"),"-o","Dir::Cache::pkgcache=","-o","Dir::Cache::srcpkgcache=","-o","Acquire::Languages=none","-o","Acquire::IndexTargets::deb::Packages::DefaultEnabled=false","-o","Acquire::IndexTargets::deb::Translations::DefaultEnabled=false","-o","Acquire::IndexTargets::deb::DEP-11::DefaultEnabled=false"])
    except InstallError as error:
        raise InstallError("Online installation cannot reach every configured repository. Connect to the internet and retry, or choose an installation without package updates. No drive changes have started. "+str(error)) from error


def state(runner,target):
    try:
        result=runner.run(["chroot",str(target),"python3","-c",STATE_SCRIPT],timeout=120)
        return json.loads(result.stdout)
    except (ValueError,subprocess.TimeoutExpired) as error:
        raise InstallError("The installed package state could not be verified. See the installation log.") from error


def save_result(target,value):
    path=pathlib.Path(target)/"var/log/amogos-installer/package-updates.json"
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2)+"\n")
    path.chmod(0o644)


def full_upgrade(runner,target,report):
    result=dict(completed=False,source="configured APT repositories",startedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    try:
        before=state(runner,target)
        if before["protectedRemovals"]:
            raise InstallError("The update would remove required AmogOS packages: "+", ".join(before["protectedRemovals"]))
        report.emit("updates",.83,"Installing all available system package updates")
        def progress(line):
            match=re.match(r"pmstatus:[^:]*:([0-9.]+):(.*)",line.strip())
            if match:
                report.emit("updates",.83+min(100,float(match[1]))*.0004,"Updating system packages: "+match[2].strip())
        command=["chroot",str(target),"apt-get",*NETWORK_OPTIONS,*INSTALL_OPTIONS,"-y","dist-upgrade"]
        try:
            runner.stream(command,progress)
        except InstallError as error:
            report.emit("updates",.87,"Finishing package configuration and retrying updates")
            result["recoveryAttempted"]=True
            result["initialError"]=str(error)
            try:
                runner.run(["chroot",str(target),"dpkg","--configure","-a"],timeout=1800)
                runner.stream(command,progress)
            except (InstallError,subprocess.TimeoutExpired) as retry_error:
                raise InstallError("Online package updates did not finish. Reconnect and repair the target using the installation log; the system has not been marked up to date. "+str(retry_error)) from retry_error
        runner.run(["chroot",str(target),"apt-get","check"],timeout=180)
        audit=runner.run(["chroot",str(target),"dpkg","--audit"],timeout=180)
        after=state(runner,target)
        result.update(pending=after["pending"],broken=after["broken"],configurationAudit=audit.stdout.strip())
        if after["pending"] or after["broken"] or audit.stdout.strip():
            names=[p["id"] for p in after["pending"]]
            raise InstallError("The online installation still has pending or unfinished package updates. "+", ".join(names[:15])+". See /var/log/amogos-installer/package-updates.json.")
        result.update(completed=True,installedPackages=len(after["installed"]),upgraded=[dict(id=key,fromVersion=before["installed"].get(key,""),version=version) for key,version in after["installed"].items() if before["installed"].get(key)!=version],removed=[key for key in before["installed"] if key not in after["installed"]])
        report.emit("updates",.875,"Verified: all "+str(len(after["installed"]))+" installed system packages are up to date")
    except InstallError as error:
        result["error"]=str(error)
        raise
    finally:
        result["finishedUtc"]=datetime.datetime.now(datetime.timezone.utc).isoformat()
        save_result(target,result)


def configure_packages(runner,target,report,drivers,upgrade):
    report.emit("drivers",.77,"Checking your hardware support")
    indexes_ready=False
    if upgrade or (drivers and online()):
        try:
            refresh(runner,target)
            indexes_ready=True
        except InstallError as error:
            if upgrade:
                save_result(target,dict(completed=False,phase="repository refresh",error=str(error),finishedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat()))
                raise
            report.emit("drivers",.78,"Repository refresh failed; checking the bundled offline hardware packages.",warning=True)
    install_drivers(runner,str(target),report,drivers,indexes_ready)
    if upgrade:
        full_upgrade(runner,target,report)
