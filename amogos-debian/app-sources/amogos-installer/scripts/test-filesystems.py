# Destructive filesystem tests operate exclusively on verified disposable loop-backed images.
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "backend"))
from amogos_install.installer import Installer
from amogos_install.planner import GIB, MIB, make_plan
from amogos_install.runtime import Reporter, Runner, private_mounts
from amogos_install.storage import read_table, shrink_limit

WORK = pathlib.Path("/srv/chocolatier/cache/storage-tests")
WORK.mkdir(parents=True, exist_ok=True)
runner = Runner()
private_mounts(runner)
results = []


def verify_loop(device, image):
    if not re.fullmatch(r"/dev/loop\d+", device):
        raise RuntimeError("Refusing a non-loop test device")
    name = pathlib.Path(device).name
    actual = pathlib.Path("/sys/class/block", name, "loop/backing_file").read_text().strip()
    if pathlib.Path("/" + actual.lstrip("/")).resolve() != image.resolve() or not image.resolve().is_relative_to(WORK.resolve()):
        raise RuntimeError("The test device is not backed by the intended disposable image")


for filesystem in ("ext4", "ntfs"):
    image = WORK / (filesystem + "-disposable.img")
    if image.exists():
        raise SystemExit("A previous disposable image exists; inspect it before retrying.")
    with image.open("xb") as out:
        out.truncate(64 * GIB)
    loop = runner.run(["losetup", "--find", "--show", "--partscan", str(image)]).stdout.strip()
    mount = WORK / (filesystem + "-mount")
    mount.mkdir(exist_ok=True)
    success = False
    try:
        verify_loop(loop, image)
        runner.run(["parted", "--script", loop, "mklabel", "gpt"])
        runner.run(["parted", "--script", loop, "mkpart", "ESP", "fat32", "1MiB", "513MiB"])
        runner.run(["parted", "--script", loop, "set", "1", "esp", "on"])
        runner.run(["parted", "--script", loop, "mkpart", "Existing", filesystem, "513MiB", "100%"])
        runner.run(["partprobe", loop]); runner.run(["udevadm", "settle"])
        esp, source = loop + "p1", loop + "p2"
        runner.run(["mkfs.fat", "-F", "32", esp])
        runner.run(["mount", esp, str(mount)])
        bootfile = mount / "EFI/Microsoft/Boot/bootmgfw.efi"
        bootfile.parent.mkdir(parents=True)
        bootfile.write_bytes(b"Preserved EFI fixture: this is not a Windows executable.\n")
        esp_hash = hashlib.sha256(bootfile.read_bytes()).hexdigest()
        runner.run(["umount", str(mount)])
        marker = WORK / (filesystem + "-marker.txt")
        marker.write_text("Keep the user's existing files byte-for-byte.\n")
        if filesystem == "ntfs":
            runner.run(["mkfs.ntfs", "--quick", "--force", source], timeout=300)
            runner.run(["ntfscp", source, str(marker), "/preserved.txt"])
        else:
            runner.run(["mkfs.ext4", "-F", source], timeout=300)
            runner.run(["mount", source, str(mount)])
            (mount / "preserved.txt").write_bytes(marker.read_bytes())
            runner.run(["umount", str(mount)])
        original_uuid = runner.run(["blkid", "-s", "UUID", "-o", "value", source]).stdout.strip()
        table = read_table(runner, loop)
        parts = []
        for p in table["partitions"]:
            number = int(re.search(r"(\d+)$", p["node"]).group(1))
            parts.append(dict(path=p["node"],number=number,start=p["start"]*512,size=p["size"]*512,fs="vfat" if number==1 else filesystem,os="Windows Boot Manager" if number==1 else "Existing OS fixture",esp=number==1,bios=False,uuid=runner.run(["blkid","-s","UUID","-o","value",p["node"]]).stdout.strip(),partuuid=p["uuid"],type=p["type"],mounts=[],blockedReason="",minimumSize=None))
        minimum, reason = shrink_limit(runner, parts[1])
        if minimum is None or reason:
            raise RuntimeError("Fixture is not eligible for shrink: " + reason)
        parts[1]["minimumSize"] = minimum
        disk = dict(path=loop,size=64*GIB,serial="disposable",table="gpt",tableId=table["id"],sectorSize=512,partitions=parts,free=[],blockedReason="")
        plan = make_plan(disk,dict(mode="smart",rootBytes=24*GIB,shrinkPartition=source),True)
        instance = Installer(plan,{},Reporter())
        verify_loop(loop, image)
        instance._partitions(disk)
        final = read_table(runner, loop)
        if final["partitions"][1]["start"] != table["partitions"][1]["start"]:
            raise RuntimeError("Existing partition start moved")
        if final["partitions"][1]["uuid"] != table["partitions"][1]["uuid"]:
            raise RuntimeError("Existing partition GUID changed")
        if runner.run(["blkid","-s","UUID","-o","value",source]).stdout.strip() != original_uuid:
            raise RuntimeError("Existing filesystem identity changed")
        if filesystem == "ntfs":
            content = subprocess.run(["ntfscat","--force",source,"/preserved.txt"], capture_output=True, check=True).stdout
            if content != marker.read_bytes():
                raise RuntimeError("The existing NTFS file changed")
        else:
            runner.run(["mount","-o","ro,noload",source,str(mount)])
            if (mount/"preserved.txt").read_bytes() != marker.read_bytes():
                raise RuntimeError("The existing Linux file changed")
            runner.run(["umount",str(mount)])
        runner.run(["mount","-o","ro",esp,str(mount)])
        if hashlib.sha256(bootfile.read_bytes()).hexdigest() != esp_hash:
            raise RuntimeError("The existing EFI file changed")
        runner.run(["umount",str(mount)])
        if runner.run(["blkid","-s","TYPE","-o","value",plan["root"]]).stdout.strip() != "ext4":
            raise RuntimeError("AmogOS root filesystem was not created")
        success = True
        result = dict(filesystem=filesystem,passed=True,preservedFile=True,preservedUUID=True,preservedPartitionStart=True,preservedEFI=True)
        results.append(result)
        print(json.dumps(result),flush=True)
    finally:
        runner.run(["umount",str(mount)],check=False)
        runner.run(["losetup","--detach",loop])
        if success:
            image.unlink()
(WORK/"results.json").write_text(json.dumps(results,indent=2))
