# Read-only storage discovery identifies operating systems, live media, and supported shrink limits.
import json
import os
import pathlib
import re
import socket
import tempfile
from .planner import GIB, MIB, down, up
from .runtime import InstallError, live_medium

ESP_TYPE = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
BIOS_TYPE = "21686148-6449-6e6f-744e-656564454649"


def descendants(node):
    yield node
    for child in node.get("children", []):
        yield from descendants(child)


def read_table(runner, path):
    result = runner.run(["sfdisk", "--json", path], check=False)
    if result.returncode:
        return {}
    return json.loads(result.stdout).get("partitiontable", {})


def identify_os(runner, partition):
    fs = partition["fs"]
    if fs not in ("ntfs", "ext4", "ext3", "ext2", "btrfs", "vfat", "xfs"):
        return ""
    with tempfile.TemporaryDirectory(prefix="amogos-probe-", dir="/run") as folder:
        options = {"ntfs": "ro,norecover", "ext4": "ro,noload", "ext3": "ro,noload", "btrfs": "ro,nologreplay"}.get(fs, "ro")
        args = ["mount", "-o", options]
        if fs == "ntfs":
            args += ["-t", "ntfs-3g"]
        result = runner.run(args + [partition["path"], folder], check=False, timeout=20)
        if result.returncode:
            return ""
        try:
            root = pathlib.Path(folder)
            if partition.get("esp"):
                partition["availableBytes"] = os.statvfs(root).f_bavail * os.statvfs(root).f_frsize
            if (root / "Windows/System32").is_dir() or (root / "WINDOWS/system32").is_dir():
                return "Windows"
            if (root / "EFI/Microsoft/Boot/bootmgfw.efi").is_file():
                return "Windows Boot Manager"
            release = root / "etc/os-release"
            if release.is_symlink():
                link = os.readlink(release)
                release = (root / link.lstrip("/")) if link.startswith("/") else (release.parent / link).resolve()
                if not release.resolve().is_relative_to(root.resolve()):
                    release = root / "usr/lib/os-release"
            if release.is_file() and release.resolve().is_relative_to(root.resolve()):
                match = re.search(r'^PRETTY_NAME=["\']?([^"\n\']+)', release.read_text(errors="replace"), re.M)
                if match:
                    return match.group(1)
            return ""
        finally:
            runner.run(["umount", folder])


def shrink_limit(runner, partition):
    if partition["mounts"]:
        return None, "Mounted filesystems must be unmounted before partition changes."
    fs, path = partition["fs"], partition["path"]
    if fs in ("BitLocker", "crypto_LUKS"):
        return None, "Encrypted volumes are preserved; unlock and prepare free space outside this installer."
    if fs == "ntfs":
        clean = runner.run(["ntfs-3g.probe", "--readwrite", path], check=False, timeout=30)
        if clean.returncode:
            return None, "NTFS is hibernated, dirty, locked, or not ready for writing. Shut Windows down fully and check the filesystem first."
        result = runner.run(["ntfsresize", "--info", "--no-action", path], check=False, timeout=90)
        if result.returncode:
            return None, "NTFS could not be validated for safe shrinking."
        found = re.search(r"You might resize at\s+(\d+)\s+bytes", result.stdout)
        if found:
            return up(max(int(found.group(1)) * 1.3 + 8 * GIB, 32 * GIB)), ""
        return None, ""
    if fs == "ext4":
        header = runner.run(["dumpe2fs", "-h", path], check=False).stdout
        state = re.search(r"Filesystem state:\s+(.+)", header)
        if not state or state.group(1).strip() != "clean":
            return None, "The Linux filesystem needs an offline filesystem check before shrinking."
        estimate = runner.run(["resize2fs", "-P", path], check=False, timeout=90)
        block_size = re.search(r"Block size:\s+(\d+)", header)
        minimum = re.search(r"minimum size of the filesystem:\s+(\d+)", estimate.stdout)
        if estimate.returncode == 0 and minimum and block_size:
            floor = int(minimum.group(1)) * int(block_size.group(1))
            return up(max(floor * 1.3 + 4 * GIB, 16 * GIB)), ""
    if fs in ("btrfs", "xfs", "LVM2_member", "linux_raid_member"):
        return None, "Automatic shrinking is unavailable for this filesystem or volume manager; use existing free space."
    return None, ""


def probe_disks(runner, *, inspect=True):
    raw = json.loads(runner.run(["lsblk", "--json", "--bytes", "--paths", "-o", "NAME,PATH,TYPE,SIZE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL,RO,PKNAME"]).stdout)
    medium = live_medium()
    media_source = runner.run(["findmnt", "-n", "-o", "SOURCE", "-T", str(medium)], check=False).stdout.strip() if medium else ""
    protected = set()
    if media_source.startswith("/dev/"):
        protected.update(runner.run(["lsblk", "-s", "-n", "-r", "-o", "PATH", media_source], check=False).stdout.splitlines())
    disks = []
    for node in raw["blockdevices"]:
        if node["type"] != "disk" or node.get("ro"):
            continue
        path = node["path"]
        table = read_table(runner, path)
        sector = table.get("sectorsize", 512)
        lookup = {c["path"]: c for c in descendants(node)}
        parts = []
        blocked = ""
        if path in protected:
            blocked = "This drive contains the running installation media."
        if any(c.get("mountpoints") and any(c["mountpoints"]) for c in descendants(node)):
            blocked = blocked or "This drive contains mounted filesystems. Unmount them before continuing."
        if any(c["type"] not in ("disk", "part") for c in descendants(node)):
            blocked = blocked or "This drive contains active LVM, RAID, or encrypted device mappings."
        for entry in table.get("partitions", []):
            child = lookup.get(entry["node"], {})
            number = re.search(r"(\d+)$", entry["node"])
            part_type = entry.get("type", "").lower()
            p = dict(path=entry["node"], number=int(number.group(1)), start=entry["start"] * sector, size=entry["size"] * sector, fs=child.get("fstype") or "", uuid="", partuuid=entry.get("uuid", ""), type=part_type, mounts=[x for x in child.get("mountpoints", []) if x], esp=part_type in (ESP_TYPE, "ef"), bios=part_type == BIOS_TYPE, os="", minimumSize=None, blockedReason="")
            p["uuid"] = runner.run(["blkid", "-s", "UUID", "-o", "value", p["path"]], check=False).stdout.strip()
            if inspect and not blocked and not p["mounts"]:
                p["os"] = identify_os(runner, p)
                p["minimumSize"], p["blockedReason"] = shrink_limit(runner, p)
            parts.append(p)
        parts.sort(key=lambda p: p["start"])
        free = []
        start = MIB
        for p in parts:
            if down(p["start"]) - up(start) >= MIB:
                free.append(dict(start=up(start), size=down(p["start"]) - up(start)))
            start = max(start, p["start"] + p["size"])
        end = down(int(node["size"]) - 2 * MIB)
        if end - up(start) >= MIB:
            free.append(dict(start=up(start), size=end - up(start)))
        disks.append(dict(path=path, model=(node.get("model") or "Storage drive").strip(), serial=node.get("serial") or "", size=int(node["size"]), sectorSize=sector, table=table.get("label", ""), tableId=table.get("id", ""), partitions=parts, free=free, blockedReason=blocked, wholeFilesystem=node.get("fstype") or ""))
    return disks


def disk_by_path(runner, path, *, inspect=True):
    if not isinstance(path, str) or not re.fullmatch(r"/dev/[A-Za-z0-9_-]+", path):
        raise InstallError("Choose a physical drive returned by the hardware scan.")
    disk = next((d for d in probe_disks(runner, inspect=inspect) if d["path"] == path), None)
    if not disk:
        raise InstallError("The selected physical drive is no longer available.")
    if disk["blockedReason"]:
        raise InstallError(disk["blockedReason"])
    return disk


def online():
    try:
        with socket.create_connection(("deb.debian.org", 443), timeout=3):
            return True
    except OSError:
        return False
