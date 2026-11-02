# Bootloader writers keep GRUB and systemd-boot placement tied to the reviewed target.
import pathlib
import re
import shutil
from .branding import PRODUCT, EFI_ID
from .runtime import InstallError


class Bootloader:
    def __init__(self, runner, target, plan, reporter):
        self.runner, self.target, self.plan, self.report = runner, pathlib.Path(target), plan, reporter

    def chroot(self, args, **kwargs):
        return self.runner.run(["chroot", str(self.target), *args], **kwargs)

    def uuid(self, device):
        value = self.runner.run(["blkid", "-s", "UUID", "-o", "value", device]).stdout.strip()
        if not re.fullmatch(r"[A-Za-z0-9-]+", value):
            raise InstallError("The boot filesystem has no valid UUID.")
        return value

    def write(self, path, text, executable=False):
        file = self.target / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)
        if executable:
            file.chmod(0o755)

    def register(self, loader):
        device = self.plan["esp"]
        number = re.search(r"(\d+)$", device).group(1)
        result = self.runner.run(["efibootmgr", "--create", "--disk", self.plan.get("bootDisk", self.plan["disk"]), "--part", number, "--label", PRODUCT, "--loader", loader], check=False)
        if result.returncode and not self.plan["newEsp"]:
            raise InstallError("The system was copied, but its firmware entry could not be created. Existing EFI files were preserved; see the installation log.")
        if result.returncode:
            self.report.emit("bootloader", .93, "Firmware registration was unavailable; the removable EFI fallback is installed.", warning=True)

    def install(self):
        loader = self.plan.get("bootloader", "grub")
        if loader == "none":
            self.report.emit("bootloader", .96, "Bootloader skipped. Add this installation to your existing loader before restarting. Root UUID: " + self.uuid(self.plan["root"]), warning=True)
        elif loader == "grub":
            self.grub()
        elif loader == "systemd-boot":
            self.systemd()
        else:
            raise InstallError("Unsupported bootloader.")

    def grub(self):
        self.write("etc/default/grub.d/90-amogos.cfg", '# Boot settings for AmogOS 2 Pro.\nGRUB_DISTRIBUTOR="AmogOS 2 Pro"\nGRUB_TIMEOUT_STYLE=menu\nGRUB_TIMEOUT=5\nGRUB_CMDLINE_LINUX_DEFAULT="quiet splash"\nGRUB_DISABLE_OS_PROBER=false\n')
        disk = self.plan.get("bootDisk", self.plan["disk"])
        table = self.plan.get("bootTable", self.plan["table"])
        if self.plan["bios"] or (not self.plan["uefi"] and table == "dos"):
            self.chroot(["grub-install", "--target=i386-pc", "--recheck", disk], timeout=180)
        if self.plan["esp"]:
            args = ["grub-install", "--target=x86_64-efi", "--efi-directory=/boot/efi", "--bootloader-id=" + EFI_ID, "--no-nvram", "--recheck"]
            self.chroot(args, timeout=180)
            if self.plan["newEsp"]:
                self.chroot(args + ["--removable"], timeout=180)
            microsoft = self.target / "boot/efi/EFI/Microsoft/Boot/bootmgfw.efi"
            if microsoft.is_file():
                uuid = self.uuid(self.plan["esp"])
                self.write("etc/grub.d/41_amogos_windows", "#!/bin/sh\ncat <<'GRUB'\nmenuentry 'Windows Boot Manager' --class windows {\ninsmod part_gpt\ninsmod fat\ninsmod chain\nsearch --no-floppy --fs-uuid --set=root " + uuid + "\nchainloader /EFI/Microsoft/Boot/bootmgfw.efi\n}\nGRUB\n", executable=True)
            if self.plan["uefi"]:
                self.register("\\EFI\\" + EFI_ID + "\\grubx64.efi")
        self.chroot(["update-grub"], timeout=300)

    def systemd(self):
        if not self.plan["uefi"] or not self.plan["esp"]:
            raise InstallError("systemd-boot requires UEFI and a selected EFI system partition.")
        esp = self.target / "boot/efi"
        kernel_files = [p for p in (self.target / "boot").glob("vmlinuz-*") if p.is_file()]
        required = 32*1048576
        for kernel in kernel_files:
            initrd = self.target / "boot" / kernel.name.replace("vmlinuz-", "initrd.img-", 1)
            if initrd.is_file():
                required += kernel.stat().st_size + initrd.stat().st_size
        if shutil.disk_usage(esp).free < required:
            raise InstallError("The selected EFI partition does not have enough space for the kernels and initramfs. Use a larger EFI partition or choose GRUB.")
        fallback = esp / "EFI/BOOT/BOOTX64.EFI"
        backup = fallback.read_bytes() if fallback.exists() and not self.plan["newEsp"] else None
        try:
            self.chroot(["bootctl", "--esp-path=/boot/efi", "--no-variables", "install"], timeout=180)
        finally:
            if backup is not None:
                fallback.write_bytes(backup)
        uuid = self.uuid(self.plan["root"])
        sync = _SYNC_SCRIPT.replace("@ROOT_UUID@", uuid)
        self.write("usr/local/libexec/amogos2pro-boot-sync", sync, executable=True)
        hook = '#!/bin/sh\nexec /usr/local/libexec/amogos2pro-boot-sync "$1"\n'
        self.write("etc/kernel/postinst.d/zz-amogos2pro-systemd-boot", hook, executable=True)
        self.write("etc/initramfs/post-update.d/zz-amogos2pro-systemd-boot", hook, executable=True)
        self.write("boot/efi/loader/loader.conf", "# Default boot entry for AmogOS 2 Pro.\ndefault amogos2pro-*.conf\ntimeout 5\nconsole-mode keep\neditor no\n")
        for kernel in kernel_files:
            self.chroot(["/usr/local/libexec/amogos2pro-boot-sync", kernel.name.removeprefix("vmlinuz-")], timeout=180)
        if self.plan["uefi"]:
            self.register("\\EFI\\systemd\\systemd-bootx64.efi")


_SYNC_SCRIPT = r'''#!/usr/bin/python3
import pathlib,re,shutil,subprocess,sys
version=sys.argv[1] if len(sys.argv)>1 else ""
if not re.fullmatch(r"[0-9][A-Za-z0-9+._-]*",version):
    raise SystemExit("Invalid kernel version")
esp=pathlib.Path("/boot/efi")
if not esp.is_mount():
    subprocess.run(["mount","/boot/efi"],check=True)
kernel=pathlib.Path("/boot")/("vmlinuz-"+version)
initrd=pathlib.Path("/boot")/("initrd.img-"+version)
if not kernel.is_file() or not initrd.is_file():
    raise SystemExit(0)
directory=esp/"EFI/AmogOS2Pro/@ROOT_UUID@"/version
directory.mkdir(parents=True,exist_ok=True)
for source,name in [(kernel,"vmlinuz"),(initrd,"initrd.img")]:
    temporary=directory/(name+".new")
    shutil.copyfile(source,temporary)
    temporary.replace(directory/name)
entry=esp/"loader/entries"/("amogos2pro-@ROOT_UUID@-"+version+".conf")
entry.parent.mkdir(parents=True,exist_ok=True)
entry.write_text("\n".join(["title AmogOS 2 Pro","sort-key amogos2pro","version "+version,"linux /EFI/AmogOS2Pro/@ROOT_UUID@/"+version+"/vmlinuz","initrd /EFI/AmogOS2Pro/@ROOT_UUID@/"+version+"/initrd.img","options root=UUID=@ROOT_UUID@ rw quiet splash"])+"\n")
'''
