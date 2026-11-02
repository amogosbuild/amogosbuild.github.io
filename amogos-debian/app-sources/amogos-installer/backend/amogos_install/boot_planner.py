# Firmware-aware boot selection validates custom destinations before partition changes.
from .planner_values import GIB, MIB
from .runtime import InstallError


def select_boot(disk, request, uefi, disks, initialize):
    loader = request.get("bootloader", "grub")
    placement = request.get("bootPlacement", "auto")
    if loader not in ("grub", "systemd-boot", "none") or placement not in ("auto", "custom"):
        raise InstallError("Select a supported bootloader and placement mode.")
    if loader == "systemd-boot" and not uefi:
        raise InstallError("systemd-boot requires UEFI. Choose GRUB for a legacy BIOS installation.")
    if loader == "none":
        return dict(loader=loader, disk=disk["path"], esp=None, bios=None, needEsp=False, needBios=False, espBytes=0, external=None, description="Keep your existing bootloader; add AmogOS 2 Pro manually", warnings=["No bootloader or firmware entry will be installed. Add the installed kernel and root filesystem to your existing bootloader before restarting."])
    path = request.get("bootDisk") if placement == "custom" else disk["path"]
    target = next((d for d in disks if d["path"] == path), None)
    if not target:
        raise InstallError("Choose an available boot disk from the hardware scan.")
    if target.get("blockedReason"):
        raise InstallError("Boot destination: " + target["blockedReason"])
    external = target["path"] != disk["path"]
    selected = request.get("bootPartition") if placement == "custom" else None
    if not selected and request.get("mode") == "manual":
        selected = request.get("manualEsp") if uefi else None
    if selected == "auto":
        selected = None
    parts = [] if initialize and not external else target["partitions"]
    table = "gpt" if initialize and not external else target.get("table")
    if table not in ("gpt", "dos"):
        raise InstallError("The custom boot disk needs an existing GPT or MBR partition table.")
    if uefi and table != "gpt":
        raise InstallError("Select a GPT disk with an EFI system partition for UEFI boot.")
    esps = [p for p in parts if p.get("esp") and p["fs"] == "vfat" and p["size"] >= 100*MIB and not p.get("mounts")]
    bios_parts = [p for p in parts if p.get("bios") and not p.get("fs") and p["size"] >= MIB and not p.get("mounts")]
    if selected:
        candidates = esps if uefi else bios_parts
        if selected not in {p["path"] for p in candidates}:
            raise InstallError("Choose an unmounted FAT EFI partition for UEFI, or the reserved BIOS boot partition for legacy GPT. Filesystem boot sectors are not supported.")
        candidates = [p for p in candidates if p["path"] == selected]
        if uefi:
            esps = candidates
        else:
            bios_parts = candidates
    if not uefi and table == "gpt" and sum(bool(p.get("bios")) for p in parts) > 1:
        raise InstallError("This disk has multiple BIOS boot partitions. Prepare an unambiguous boot layout before installing.")
    if external and ((uefi and not esps) or (not uefi and table == "gpt" and not bios_parts)):
        raise InstallError("The other boot disk must already contain the appropriate EFI or BIOS boot partition. It will not be repartitioned automatically.")
    esp = esps[0]["path"] if esps and (uefi or placement == "auto") else None
    bios = bios_parts[0]["path"] if bios_parts and loader == "grub" else None
    both = initialize and placement == "auto" and loader == "grub"
    need_esp = not external and not esp and (uefi or both)
    need_bios = not external and not bios and table == "gpt" and loader == "grub" and (not uefi or both)
    if loader == "systemd-boot" and esps:
        p = esps[0]
        if p["size"] < 512*MIB or p.get("availableBytes", p["size"]) < 256*MIB:
            raise InstallError("systemd-boot needs an EFI partition of at least 512 MiB with 256 MiB free. Choose a larger ESP or use GRUB.")
    destination = esp or bios or target["path"]
    name = "GRUB" if loader == "grub" else "systemd-boot"
    warnings = []
    if loader == "systemd-boot":
        warnings.append("systemd-boot finds Windows and compatible boot entries on the selected EFI partition. GRUB is recommended for broader Linux multi-boot detection.")
    return dict(loader=loader, disk=target["path"], esp=esp, bios=bios, needEsp=need_esp, needBios=need_bios, espBytes=GIB if loader=="systemd-boot" else 512*MIB, external=target if external else None, description=f"{name} · {'automatic placement' if placement=='auto' else 'custom placement'} · {destination}", warnings=warnings)
