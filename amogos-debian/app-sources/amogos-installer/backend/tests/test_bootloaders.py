# Boot regression tests exercise cross-disk plans, preserved EFI files, and kernel update entries.
import copy
import pathlib
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_install.bootloaders import Bootloader, _SYNC_SCRIPT
from amogos_install.planner import GIB, MIB, make_plan
from amogos_install.runtime import InstallError
from test_planner import fixture


def other_disk():
    disk = fixture()
    disk.update(path="/dev/sdb", serial="other-disk")
    disk["partitions"] = [dict(disk["partitions"][0], path="/dev/sdb1", size=GIB, availableBytes=700*MIB)]
    return disk


class Recorder:
    def __init__(self):
        self.commands = []

    def run(self, args, **kwargs):
        self.commands.append(args)
        return SimpleNamespace(stdout="abcd-1234", returncode=0)

    def emit(self, *args, **kwargs):
        pass


class BootloaderTests(unittest.TestCase):
    def test_custom_efi_on_other_disk_is_preserved_and_confirmed(self):
        disk, boot = fixture(), other_disk()
        before = copy.deepcopy(boot)
        plan = make_plan(disk, dict(mode="erase", bootloader="grub", bootPlacement="custom", bootDisk="/dev/sdb", bootPartition="/dev/sdb1"), True, [disk, boot])
        self.assertEqual(plan["esp"], "/dev/sdb1")
        self.assertEqual(plan["bootDisk"], "/dev/sdb")
        self.assertEqual(plan["confirmation"], "nvme0n1 + sdb")
        self.assertFalse(plan["newEsp"])
        self.assertEqual(len(plan["bootTargets"]), 1)
        self.assertFalse(any(s.get("path", "").startswith("/dev/sdb") for s in plan["steps"]))
        self.assertEqual(boot, before)

    def test_foreign_mounted_and_missing_efi_targets_rejected(self):
        disk = fixture()
        for alteration in ("missing", "mounted", "noesp"):
            boot = other_disk()
            if alteration == "mounted":
                boot["blockedReason"] = "Mounted data filesystem"
            if alteration == "noesp":
                boot["partitions"] = []
            with self.assertRaises(InstallError):
                make_plan(disk, dict(mode="erase", bootPlacement="custom", bootDisk="/dev/missing" if alteration=="missing" else "/dev/sdb"), True, [disk, boot])

    def test_systemd_rejects_bios_and_insufficient_efi_space(self):
        disk = fixture()
        with self.assertRaises(InstallError):
            make_plan(disk, dict(mode="erase", bootloader="systemd-boot"), False)
        disk["partitions"][0]["availableBytes"] = 128*MIB
        with self.assertRaises(InstallError):
            make_plan(disk, dict(mode="smart", bootloader="systemd-boot", rootBytes=32*GIB), True)
        plan = make_plan(disk, dict(mode="erase", bootloader="systemd-boot"), True)
        self.assertEqual([s["size"] for s in plan["steps"] if s.get("role")=="esp" and s["action"]=="create"], [GIB])
        self.assertIsNone(plan["bios"])

    def test_skip_does_not_allocate_boot_partitions_or_write_a_loader(self):
        plan = make_plan(fixture(), dict(mode="erase", bootloader="none"), True)
        self.assertIsNone(plan["esp"])
        self.assertIsNone(plan["bios"])
        runner = Recorder()
        with tempfile.TemporaryDirectory() as target:
            Bootloader(runner, target, plan, runner).install()
            self.assertEqual(list(pathlib.Path(target).iterdir()), [])
        self.assertEqual([c[0] for c in runner.commands], ["blkid"])

    def test_grub_uses_reviewed_boot_disk_and_preserves_shared_fallback(self):
        plan = make_plan(fixture(), dict(mode="erase"), True)
        plan.update(bootDisk="/dev/sdb", esp="/dev/sdb1", bios="/dev/sdb2", newEsp=False)
        runner = Recorder()
        with tempfile.TemporaryDirectory() as target:
            Bootloader(runner, target, plan, runner).install()
        bios = next(c for c in runner.commands if "--target=i386-pc" in c)
        self.assertEqual(bios[-1], "/dev/sdb")
        firmware = next(c for c in runner.commands if c[0]=="efibootmgr")
        self.assertEqual(firmware[firmware.index("--disk")+1], "/dev/sdb")
        self.assertEqual(firmware[firmware.index("--part")+1], "1")
        self.assertFalse(any("--removable" in c for c in runner.commands))

    def test_kernel_hook_writes_real_bls_lines_and_updates_initramfs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            boot, esp = root/"boot", root/"esp"
            boot.mkdir(); esp.mkdir()
            version = "6.12.94+deb13-amd64"
            (boot/("vmlinuz-"+version)).write_bytes(b"kernel")
            initrd = boot/("initrd.img-"+version)
            initrd.write_bytes(b"initramfs-v1")
            script = _SYNC_SCRIPT.replace("@ROOT_UUID@", "abcd-1234").replace('pathlib.Path("/boot/efi")', "pathlib.Path("+repr(str(esp))+")").replace('pathlib.Path("/boot")', "pathlib.Path("+repr(str(boot))+")").replace("if not esp.is_mount():", "if False:")
            hook = root/"hook.py"
            hook.write_text(script)
            subprocess.run([sys.executable, str(hook), version], check=True)
            entry = next((esp/"loader/entries").glob("*.conf"))
            self.assertEqual(entry.read_text().splitlines()[0], "title AmogOS 2 Pro")
            self.assertIn("options root=UUID=abcd-1234 rw quiet splash", entry.read_text().splitlines())
            initrd.write_bytes(b"initramfs-v2")
            subprocess.run([sys.executable, str(hook), version], check=True)
            self.assertEqual((esp/"EFI/AmogOS2Pro/abcd-1234"/version/"initrd.img").read_bytes(), b"initramfs-v2")
            self.assertFalse(list(esp.rglob("*.new")))


if __name__ == "__main__":
    unittest.main()
