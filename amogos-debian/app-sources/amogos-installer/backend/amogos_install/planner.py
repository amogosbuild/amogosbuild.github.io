# Pure partition planning preserves existing extents and rejects unsafe or ambiguous layouts.
import hashlib
import json
import math
from .runtime import InstallError
from .boot_planner import select_boot
from .planner_values import GIB, MIB

MIN_ROOT = 24 * GIB
ESP_BYTES = 512 * MIB
BIOS_BYTES = 2 * MIB


def up(value):
    return math.ceil(value / MIB) * MIB


def down(value):
    return value // MIB * MIB


def fingerprint(disk):
    fields = {key: disk.get(key) for key in ("path", "size", "serial", "table", "sectorSize", "tableId")}
    fields["partitions"] = [{k: p.get(k) for k in ("path", "number", "start", "size", "uuid", "partuuid", "type")} for p in disk["partitions"]]
    return hashlib.sha256(json.dumps(fields, sort_keys=True).encode()).hexdigest()


def make_plan(disk, request, uefi, disks=None):
    if disk.get("blockedReason"):
        raise InstallError(disk["blockedReason"])
    mode = request.get("mode")
    if mode not in ("smart", "erase", "manual"):
        raise InstallError("Choose smart, erase, or manual installation.")
    if not disk["partitions"] and disk.get("wholeFilesystem") and mode != "erase":
        raise InstallError("This drive has a filesystem without a partition table. Choose explicit erase only if its data can be removed, or prepare partitions outside the installer.")
    if disk["size"] < MIN_ROOT + ESP_BYTES + BIOS_BYTES + 4 * MIB:
        raise InstallError("This drive is too small. Use a drive with at least 25 GiB available.")
    root_bytes = MIN_ROOT if mode == "erase" or (mode == "manual" and request.get("manualRoot") not in (None, "new")) else request.get("rootBytes", 80 * GIB)
    if type(root_bytes) is not int or not MIN_ROOT <= root_bytes <= disk["size"]:
        raise InstallError("Choose at least 24 GiB for AmogOS, within the size of this drive.")
    parts = disk["partitions"]
    warnings, descriptions, steps = [], [], []
    preserved = sorted({p["os"] for p in parts if p.get("os")})
    table = disk.get("table", "")
    initialize = mode == "erase" or (not parts and table not in ("gpt", "dos"))
    if initialize:
        table = "gpt"
        steps.append(dict(action="label", table="gpt"))
        descriptions.append("Create a new GPT partition table" + (" and erase every existing partition" if mode == "erase" else ""))
        if mode == "erase":
            warnings.append("Every existing partition and file on this drive will be erased.")
            preserved = []
    elif table not in ("gpt", "dos"):
        raise InstallError("This partition-table type needs manual preparation with a partition editor.")
    boot = select_boot(disk, request, uefi, disks or [disk], initialize)
    esp, bios = boot["esp"], boot["bios"]
    warnings.extend(boot["warnings"])
    manual_root = None
    if mode == "manual" and request.get("manualRoot") not in (None, "new"):
        manual_root = next((p for p in parts if p["path"] == request["manualRoot"]), None)
        if not manual_root or manual_root.get("esp") or manual_root.get("bios") or manual_root.get("mounts"):
            raise InstallError("Select an unmounted data partition for the AmogOS root filesystem.")
        if manual_root["size"] < MIN_ROOT or manual_root["fs"] in ("crypto_LUKS", "BitLocker", "LVM2_member", "linux_raid_member"):
            raise InstallError("The selected root partition is too small, encrypted, or managed by LVM/RAID.")
        if manual_root.get("os"):
            warnings.append(f"Formatting {manual_root['path']} will remove {manual_root['os']} and all files on that partition.")
            preserved = [x for x in preserved if x != manual_root["os"]]
    elif mode == "manual" and request.get("manualRoot") != "new":
        raise InstallError("Assign a root partition, or choose to create one in free space.")
    need_esp, need_bios = boot["needEsp"], boot["needBios"]
    overhead = (boot["espBytes"] if need_esp else 0) + (BIOS_BYTES if need_bios else 0)
    needed = overhead + (0 if manual_root else up(root_bytes))
    region = None
    if initialize:
        region = dict(start=MIB, size=down(disk["size"] - 3 * MIB))
        if mode == "erase":
            root_bytes = region["size"] - overhead
            needed = region["size"]
    else:
        free = [p for p in disk.get("free", []) if p["size"] >= needed]
        if request.get("freeStart") is not None:
            free = [p for p in free if p["start"] == request["freeStart"]]
        shrink_path = request.get("shrinkPartition")
        if free and shrink_path is None:
            region = max(free, key=lambda p: p["size"])
        elif not manual_root and mode == "smart" and request.get("freeStart") is None:
            candidates = [p for p in parts if p.get("minimumSize") is not None and not p.get("blockedReason") and not p.get("mounts") and p["size"] - up(p["minimumSize"]) >= needed + MIB]
            if shrink_path:
                candidates = [p for p in candidates if p["path"] == shrink_path]
            if candidates:
                candidate = max(candidates, key=lambda p: p["size"] - p["minimumSize"])
                new_end = down(candidate["start"] + candidate["size"] - needed - MIB)
                new_size = new_end - candidate["start"]
                if new_size < candidate["minimumSize"]:
                    raise InstallError("The existing filesystem needs more space than this proposal leaves.")
                steps.append(dict(action="shrink", path=candidate["path"], number=candidate["number"], fs=candidate["fs"], start=candidate["start"], size=new_size))
                descriptions.append(f"Shrink {candidate['path']} ({candidate.get('os') or candidate['fs']}) to {new_size / GIB:.1f} GiB while preserving its start and identifier")
                warnings.append("Resizing an existing filesystem needs a current backup. Windows must be fully shut down, with Fast Startup and hibernation disabled.")
                region = dict(start=new_end, size=candidate["start"] + candidate["size"] - new_end)
    if needed and region is None:
        raise InstallError("There is not enough eligible free or safely shrinkable space for this plan. Reduce the requested size or prepare space with a partition editor.")
    used = set() if initialize else {p["number"] for p in parts}
    cursor = up(region["start"]) if region else 0
    limit = down(region["start"] + region["size"]) if region else 0
    allocations = []
    def allocate(role, size, fs):
        nonlocal cursor
        number = next(n for n in range(1, 129) if n not in used)
        if table == "dos" and (number > 4 or any(p["number"] > 4 for p in parts)):
            raise InstallError("This MBR layout has no available primary partition slot. Prepare the layout manually in a partition editor.")
        used.add(number)
        size = up(size)
        if cursor + size > limit:
            raise InstallError("Partition alignment leaves insufficient space. Choose a smaller installation size.")
        value = dict(action="create", role=role, number=number, start=cursor, size=size, fs=fs)
        allocations.append(value)
        steps.append(value)
        cursor += size
        return f"{disk['path']}{'p' if disk['path'][-1].isdigit() else ''}{number}"
    if need_bios:
        bios = allocate("bios", BIOS_BYTES, "")
        descriptions.append("Create a 2 MiB BIOS boot partition")
    if need_esp:
        esp = allocate("esp", boot["espBytes"], "fat32")
        descriptions.append(f"Create a {boot['espBytes']//MIB} MiB FAT EFI system partition")
    if manual_root:
        root = manual_root["path"]
        root_bytes = manual_root["size"]
    else:
        root = allocate("root", root_bytes, "ext4")
        descriptions.append(f"Create a {up(root_bytes) / GIB:.1f} GiB AmogOS root partition")
    steps.append(dict(action="format", role="root", path=root, fs="ext4"))
    descriptions.append(f"Format {root} as ext4 for AmogOS")
    if need_esp:
        steps.append(dict(action="format", role="esp", path=esp, fs="vfat"))
    if esp and not need_esp:
        descriptions.append(f"Reuse {esp} without formatting its existing EFI files")
    if boot["loader"] != "none":
        name = "GRUB" if boot["loader"] == "grub" else "systemd-boot"
        target = esp if uefi else boot["disk"] + (f" (BIOS boot partition {bios})" if bios else " (MBR)")
        boot["description"] = f"{name} on {target}"
        if uefi and bios:
            boot["description"] += f"; legacy boot on {boot['disk']} using {bios}"
    descriptions.extend(["Copy AmogOS 2 Pro and configure your account", boot["description"]])
    extra = [dict(path=boot["external"]["path"], fingerprint=fingerprint(boot["external"]))] if boot["external"] else []
    confirmation = " + ".join(p.split("/")[-1] for p in [disk["path"]] + ([boot["disk"]] if extra else []))
    if request.get("upgrade"):
        descriptions.append("Refresh repositories, apply a full system upgrade and verify no package updates remain")
    return dict(disk=disk["path"], root=root, esp=esp, bios=bios, newEsp=need_esp, uefi=uefi, rootBytes=root_bytes, steps=steps, operations=descriptions, warnings=warnings, preserved=preserved, mode=mode, table=table, fingerprint=fingerprint(disk), drivers=bool(request.get("drivers", True)), upgrade=bool(request.get("upgrade", False)), summary={"smart":"Install alongside existing systems", "erase":"Erase the selected drive and install AmogOS 2 Pro", "manual":"Install using your partition assignments"}[mode], bootloader=boot["loader"], bootDisk=boot["disk"], bootTable="gpt" if initialize and not extra else (boot["external"]["table"] if extra else table), bootDescription=boot["description"], bootTargets=extra, confirmation=confirmation)
