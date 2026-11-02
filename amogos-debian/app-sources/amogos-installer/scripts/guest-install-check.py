# Installation integration checks require the dedicated QEMU disk and never accept a user disk.
import json
import os
import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, "/usr/lib/amogos-installer/backend")
from amogos_install.runtime import Runner, private_mounts, require_live

runner = Runner()
require_live(runner)
vendor = pathlib.Path("/sys/class/dmi/id/product_name").read_text()
serial = runner.run(["lsblk", "-n", "-d", "-o", "SERIAL", "/dev/vda"]).stdout.strip()
if not any(x in vendor for x in ("QEMU", "Standard PC")) or serial != "AMOGOS-INSTALL-TEST":
    raise SystemExit("The guest check only accepts the dedicated QEMU test disk.")
cli = ["/usr/bin/python3", "-I", "/mnt/installer-src/backend/cli.py"]
options = dict(mode="erase", disk="/dev/vda", rootBytes=24*1073741824, drivers=False, upgrade=False)
plan = json.loads(runner.run(cli + ["plan"], input=json.dumps(options), timeout=180).stdout)
request = dict(token=plan["token"], confirmation="vda", account=dict(name="Installer Test", username="amogostest", hostname="amogos-installtest", password="Installer-VM-check-2026", autoLogin=False), locale="en_GB.UTF-8", timezone="Europe/London", keyboard="gb")
process = subprocess.Popen(cli + ["install"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
process.stdin.write(json.dumps(request))
process.stdin.close()
completed = False
for line in process.stdout:
    print(line, end="", flush=True)
    try:
        event = json.loads(line)
        completed |= event.get("done") is True
    except ValueError:
        pass
if process.wait() or not completed:
    logs = sorted(pathlib.Path("/var/log/amogos-installer").glob("*/installation.log"))
    if logs:
        print(logs[-1].read_text()[-12000:], flush=True)
    raise SystemExit("INSTALL_CHECK_FAILED")
private_mounts(runner)
with tempfile.TemporaryDirectory(prefix="installed-check-", dir="/run") as folder:
    target = pathlib.Path(folder)
    runner.run(["mount", "/dev/vda3", folder])
    children = []
    try:
        fstab = (target / "etc/fstab").read_text()
        uuid = runner.run(["blkid", "-s", "UUID", "-o", "value", "/dev/vda3"]).stdout.strip()
        assert "UUID=" + uuid + " / ext4" in fstab
        assert "amogostest:" in (target / "etc/passwd").read_text()
        assert "\nuser:" not in (target / "etc/passwd").read_text()
        assert (target / "boot/grub/grub.cfg").is_file()
        assert (target / ("boot/vmlinuz-" + os.uname().release)).is_file()
        assert (target / ("boot/initrd.img-" + os.uname().release)).is_file()
        runner.run(["mount", "/dev/vda2", str(target / "boot/efi")])
        children.append(target / "boot/efi")
        assert (target / "boot/efi/EFI/BOOT/BOOTX64.EFI").is_file()
        assert (target / "boot/efi/EFI/AmogOS/grubx64.efi").is_file()
        for name in ("dev", "proc", "sys"):
            runner.run(["mount", "--rbind", "/" + name, str(target / name)])
            runner.run(["mount", "--make-rslave", str(target / name)])
            children.append(target / name)
        (target / "etc/default/grub.d/99-vm-test.cfg").write_text('GRUB_TERMINAL="console serial"\nGRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1"\nGRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8"\nGRUB_TIMEOUT=1\n')
        runner.run(["chroot", folder, "update-grub"], timeout=180)
        grub = (target / "boot/grub/grub.cfg").read_text()
        assert uuid in grub and "boot=live" not in grub
        runner.run(["sync"], timeout=180)
    finally:
        for child in reversed(children):
            runner.run(["umount", "-R", str(child)], check=False)
        runner.run(["umount", folder])
print("INSTALL_CHECK_PASSED", flush=True)
