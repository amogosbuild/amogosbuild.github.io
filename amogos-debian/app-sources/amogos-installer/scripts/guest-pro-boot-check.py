# These destructive checks accept only two dedicated disposable QEMU disks with exact serials.
import json
import os
import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, "/mnt/installer-src/backend")
from amogos_install.bootloaders import Bootloader
from amogos_install.runtime import Runner, private_mounts, require_live

r = Runner()
require_live(r)
if pathlib.Path("/sys/firmware/efi").is_dir() and not os.path.ismount("/sys/firmware/efi/efivars"):
    r.run(["mount", "-t", "efivarfs", "efivarfs", "/sys/firmware/efi/efivars"])
vendor = pathlib.Path("/sys/class/dmi/id/product_name").read_text()
if "QEMU" not in vendor and "Standard PC" not in vendor:
    raise SystemExit("Only a dedicated QEMU test guest is accepted.")
for device, serial in [("/dev/vda", "AMOGOS-PRO-ROOT-TEST"), ("/dev/vdb", "AMOGOS-PRO-BOOT-TEST")]:
    if r.run(["lsblk", "-n", "-d", "-o", "SERIAL", device]).stdout.strip() != serial:
        raise SystemExit("The disposable test disk serial does not match: " + device)
switch = "--systemd" in sys.argv
cli = ["python3", "-I", "/mnt/installer-src/backend/cli.py"]
if not switch:
    r.run(["parted", "-s", "/dev/vdb", "mklabel", "gpt", "mkpart", "EFI", "fat32", "1MiB", "1025MiB", "set", "1", "esp", "on", "mkpart", "BIOS", "1025MiB", "1027MiB", "set", "2", "bios_grub", "on"])
    r.run(["partprobe", "/dev/vdb"])
    r.run(["udevadm", "settle"])
    r.run(["mkfs.fat", "-F", "32", "/dev/vdb1"])
    with tempfile.TemporaryDirectory(dir="/run") as folder:
        r.run(["mount", "/dev/vdb1", folder])
        fallback = pathlib.Path(folder)/"EFI/BOOT/BOOTX64.EFI"
        fallback.parent.mkdir(parents=True)
        fallback.write_bytes(b"PRESERVE-EXISTING-EFI-FALLBACK")
        r.run(["umount", folder])
    options = dict(mode="erase", disk="/dev/vda", bootloader="grub", bootPlacement="custom", bootDisk="/dev/vdb", bootPartition="/dev/vdb1", drivers=False, upgrade=False)
    plan = json.loads(r.run(cli+["plan"], input=json.dumps(options), timeout=180).stdout)
    assert plan["confirmation"] == "vda + vdb"
    request = dict(token=plan["token"], confirmation=plan["confirmation"], account=dict(name="Installer Test", username="amogostest", hostname="amogos-pro-test", password="Installer-VM-check-2026", autoLogin=False), locale="en_GB.UTF-8", timezone="Europe/London", keyboard="gb")
    process = subprocess.Popen(cli+["install"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    process.stdin.write(json.dumps(request)); process.stdin.close()
    completed = False
    for line in process.stdout:
        print(line, end="", flush=True)
        try:
            completed |= json.loads(line).get("done") is True
        except ValueError:
            pass
    if process.wait() or not completed:
        logs = sorted(pathlib.Path("/var/log/amogos-installer").glob("*/installation.log"))
        if logs:
            print(logs[-1].read_text()[-16000:], flush=True)
        raise SystemExit("PRO_CHECK_FAILED")

private_mounts(r)
with tempfile.TemporaryDirectory(prefix="pro-check-", dir="/run") as folder:
    target = pathlib.Path(folder)
    mounts = []
    try:
        for device, relative in [("/dev/vda1", ""), ("/dev/vdb1", "boot/efi")]:
            destination = target/relative
            destination.mkdir(parents=True, exist_ok=True)
            r.run(["mount", device, str(destination)])
            mounts.append(destination)
        assert (target/"boot/efi/EFI/BOOT/BOOTX64.EFI").read_bytes() == b"PRESERVE-EXISTING-EFI-FALLBACK"
        assert (target/"boot/efi/EFI/AmogOS2Pro/grubx64.efi").is_file()
        assert 'PRETTY_NAME="AmogOS 2 Pro"' in (target/"etc/os-release").read_text()
        assert "Theme=amogos2pro" in (target/"etc/plymouth/plymouthd.conf").read_text()
        assert "amogostest:" in (target/"etc/passwd").read_text()
        fstab = (target/"etc/fstab").read_text()
        esp_uuid = r.run(["blkid", "-s", "UUID", "-o", "value", "/dev/vdb1"]).stdout.strip()
        assert "UUID="+esp_uuid+" /boot/efi" in fstab
        version = os.uname().release
        initrd = target/("boot/initrd.img-"+version)
        contents = r.run(["lsinitramfs", str(initrd)], timeout=180).stdout
        assert "plymouth/themes/amogos2pro/amogos2pro.script" in contents
        for name in ("dev", "proc", "sys"):
            r.run(["mount", "--rbind", "/"+name, str(target/name)])
            r.run(["mount", "--make-rslave", str(target/name)])
            mounts.append(target/name)
        if switch:
            class Reporter:
                def emit(self, *args, **kwargs):
                    print(args, kwargs, flush=True)
            plan = dict(bootloader="systemd-boot", disk="/dev/vda", root="/dev/vda1", bootDisk="/dev/vdb", esp="/dev/vdb1", bios="/dev/vdb2", uefi=True, newEsp=False, table="gpt", bootTable="gpt")
            Bootloader(r, target, plan, Reporter()).install()
            r.run(["chroot", folder, "/etc/initramfs/post-update.d/zz-amogos2pro-systemd-boot", version, "/boot/initrd.img-"+version], timeout=180)
            entry = next((target/"boot/efi/loader/entries").glob("amogos2pro-*.conf"))
            assert "title AmogOS 2 Pro" in entry.read_text().splitlines()
            initrd_path = next(line.removeprefix("initrd ") for line in entry.read_text().splitlines() if line.startswith("initrd "))
            r.run(["cmp", str(initrd), str(target/"boot/efi"/initrd_path.lstrip("/"))], timeout=180)
            text = entry.read_text().replace("rw quiet splash", "rw quiet splash console=tty0 console=ttyS0,115200n8 plymouth.ignore-serial-consoles")
            entry.write_text(text)
            assert (target/"boot/efi/EFI/BOOT/BOOTX64.EFI").read_bytes() == b"PRESERVE-EXISTING-EFI-FALLBACK"
        else:
            (target/"etc/default/grub.d/99-vm-test.cfg").write_text('GRUB_TERMINAL="console serial"\nGRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1"\nGRUB_CMDLINE_LINUX_DEFAULT="quiet splash console=tty0 console=ttyS0,115200n8 plymouth.ignore-serial-consoles"\nGRUB_TIMEOUT=1\n')
            r.run(["chroot", folder, "update-grub"], timeout=180)
            assert "boot=live" not in (target/"boot/grub/grub.cfg").read_text()
        r.run(["sync"], timeout=180)
    finally:
        for mount in reversed(mounts):
            r.run(["umount", "-R", str(mount)], check=False)
print("PRO_CHECK_PASSED", flush=True)
