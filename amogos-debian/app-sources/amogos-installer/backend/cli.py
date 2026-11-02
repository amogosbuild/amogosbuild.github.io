# Fixed-action entry point accepts bounded JSON and keeps reviewed plans private to the authorizing user.
import fcntl
import json
import os
import pathlib
import secrets
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from amogos_install.drivers import recommendations
from amogos_install.installer import Installer
from amogos_install.planner import make_plan
from amogos_install.runtime import InstallError, Reporter, Runner, live_medium, private_mounts, require_live
from amogos_install.storage import disk_by_path, online, probe_disks


def read_request():
    raw = sys.stdin.read(65537)
    if len(raw) > 65536:
        raise InstallError("The installation request is too large.")
    data = json.loads(raw or "{}")
    if not isinstance(data, dict):
        raise InstallError("The request must be a JSON object.")
    return data


def main():
    if os.geteuid() != 0:
        raise InstallError("Use the authorized installer helper for hardware and installation operations.")
    if len(sys.argv) != 2 or sys.argv[1] not in ("probe", "plan", "install"):
        raise InstallError("Only probe, plan, and install actions are available.")
    action = sys.argv[1]
    request, runner = read_request(), Runner()
    state = pathlib.Path("/run/amogos-installer")
    state.mkdir(mode=0o700, exist_ok=True)
    owner = int(os.environ.get("PKEXEC_UID", os.getuid()))
    if action == "probe":
        private_mounts(runner)
        print(json.dumps(dict(disks=probe_disks(runner), drivers=recommendations(runner), live=live_medium() is not None and runner.run(["findmnt", "-n", "-o", "FSTYPE", "/"]).stdout.strip() in ("overlay", "aufs"), uefi=pathlib.Path("/sys/firmware/efi").exists(), online=online())))
    elif action == "plan":
        require_live(runner)
        private_mounts(runner)
        disks = probe_disks(runner)
        disk = next((d for d in disks if d["path"] == request.get("disk")), None)
        if disk is None:
            raise InstallError("Choose an available installation drive.")
        plan = make_plan(disk, request, pathlib.Path("/sys/firmware/efi").exists(), disks)
        token = secrets.token_hex(32)
        plan.update(token=token, owner=owner, expires=time.time() + 3600)
        path = state / (token + ".json")
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w") as out:
            json.dump(plan, out)
        print(json.dumps({key: plan[key] for key in ("token", "disk", "summary", "operations", "warnings", "preserved", "rootBytes", "bootloader", "bootDescription", "confirmation")}))
    else:
        token = request.get("token", "")
        if not isinstance(token, str) or len(token) != 64 or any(c not in "0123456789abcdef" for c in token):
            raise InstallError("Review a valid installation plan first.")
        path = state / (token + ".json")
        if not path.is_file():
            raise InstallError("The reviewed plan is no longer available. Review a new plan.")
        plan = json.loads(path.read_text())
        if plan["owner"] != owner or plan["expires"] < time.time():
            raise InstallError("The plan expired or belongs to another session. Review it again.")
        lock = (state / "installation.lock").open("w")
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise InstallError("Another installation is already running.")
        path.unlink()
        reporter = Reporter()
        try:
            Installer(plan, request, reporter).run()
        except Exception as error:
            reporter.emit("error", reporter.progress, str(error), error=True)
            return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (InstallError, OSError, ValueError, KeyError) as error:
        print(json.dumps(dict(error=True, message=str(error))), flush=True)
        sys.exit(1)
