# Installation applies a reviewed plan only in live media and confines configuration to the mounted target.
import pathlib
import os
import pwd
import re
import shutil
import tempfile
import time
from .package_updates import configure_packages, prepare_online
from .kernels import prepare_kernels
from .planner import MIB, fingerprint
from .runtime import InstallError, Runner, log_directory, private_mounts, require_live
from .storage import disk_by_path, read_table, shrink_limit
from .bootloaders import Bootloader

SYSTEM_PACKAGE = pathlib.Path('/usr/share/amogos-installer/amogos-system.deb')
SYSTEM_VERSION = '2.1.0-2'


def validate_settings(request):
    account = request.get("account", {})
    username = account.get("username", "")
    if not isinstance(username, str) or not re.fullmatch(r"[a-z_][a-z0-9_-]{0,31}", username) or username in ("root", "daemon", "nobody", "bin", "sys", "sync", "installer"):
        raise InstallError("Choose a valid, non-system username.")
    try:
        if pwd.getpwnam(username).pw_uid < 1000:
            raise InstallError("This username belongs to a system account.")
    except KeyError:
        pass
    name, hostname, password = account.get("name", ""), account.get("hostname", ""), account.get("password", "")
    if not isinstance(name, str) or not 1 <= len(name.strip()) <= 80 or re.search(r"[:\x00\r\n]", name):
        raise InstallError("Enter a valid full name.")
    if not isinstance(hostname, str) or not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?", hostname):
        raise InstallError("Enter a valid computer name.")
    if not isinstance(password, str) or not 8 <= len(password) <= 1024 or re.search(r"[\x00\r\n]", password):
        raise InstallError("Passwords need at least eight characters and cannot contain line breaks.")
    locale = request.get("locale", "")
    supported = pathlib.Path("/usr/share/i18n/SUPPORTED").read_text() if pathlib.Path("/usr/share/i18n/SUPPORTED").exists() else ""
    if not re.fullmatch(r"[a-z]{2}_[A-Z]{2}\.UTF-8", locale) or locale not in supported:
        raise InstallError("This system language is not available on the live image.")
    timezone = request.get("timezone", "")
    if not isinstance(timezone, str) or ".." in timezone.split("/") or timezone.startswith("/"):
        raise InstallError("Invalid time zone.")
    zone = pathlib.Path("/usr/share/zoneinfo") / timezone
    if not zone.is_file() or not str(zone.resolve()).startswith("/usr/share/zoneinfo/"):
        raise InstallError("Select an available time zone.")
    keyboard = request.get("keyboard", "")
    if not re.fullmatch(r"[a-z]{2}", keyboard) or not pathlib.Path("/usr/share/X11/xkb/symbols", keyboard).is_file():
        raise InstallError("Select an available keyboard layout.")
    return account


class Installer:
    def __init__(self, plan, request, reporter):
        self.plan, self.request, self.report = plan, request, reporter
        self.runner = Runner()
        self.mounts = []
        self.target = None

    def run(self):
        medium = require_live(self.runner)
        validate_settings(self.request)
        if self.request.get("confirmation") != self.plan.get("confirmation", self.plan["disk"].split("/")[-1]):
            raise InstallError("The drive confirmation does not match the reviewed plan.")
        disk = disk_by_path(self.runner, self.plan["disk"], inspect=False)
        if fingerprint(disk) != self.plan["fingerprint"]:
            raise InstallError("The drive layout changed after review. Scan the drives and review a new plan.")
        self._validate_boot_targets()
        for step in self.plan["steps"]:
            if step["action"] == "shrink":
                partition = next(p for p in disk["partitions"] if p["path"] == step["path"])
                minimum, reason = shrink_limit(self.runner, partition)
                if reason or minimum is None or minimum > step["size"]:
                    raise InstallError("The filesystem is no longer eligible for the reviewed resize.")
        secure = next(pathlib.Path("/sys/firmware/efi/efivars").glob("SecureBoot-*"), None)
        if secure and len(secure.read_bytes()) > 4 and secure.read_bytes()[4] == 1:
            raise InstallError("This development image does not include a signed Secure Boot chain.")
        folder = log_directory()
        self.runner.log = (folder / "installation.log").open("w", buffering=1)
        (folder / "partition-table.before").write_text(self.runner.run(["sfdisk", "--dump", disk["path"]], check=False).stdout)
        self.report.emit("prepare", .02, "Checking the live system and reviewed layout")
        try:
            if self.plan["upgrade"]:
                prepare_online(self.runner,self.report)
            private_mounts(self.runner)
            self.target = pathlib.Path(tempfile.mkdtemp(prefix="amogos-target-", dir="/run"))
            self._partitions(disk)
            self._mount(self.plan["root"], self.target)
            self._copy(medium)
            self._validate_boot_targets()
            if self.plan["esp"]:
                (self.target / "boot/efi").mkdir(parents=True, exist_ok=True)
                self._mount(self.plan["esp"], self.target / "boot/efi")
            self._runtime()
            self._configure()
            self._ensure_system_core()
            self._packages()
            self._boot(medium)
            self._remove_live_tools()
            self.report.emit("finish", .98, "Syncing your new system to disk")
            self.chroot(["apt-get", "clean"], check=False)
            self.runner.run(["sync"], timeout=180)
        finally:
            self.runner.log.flush()
            if self.target and (self.target / "etc/os-release").exists():
                try:
                    shutil.copytree(folder, self.target / "var/log/amogos-installer" / folder.name, dirs_exist_ok=True)
                except OSError:
                    pass
            for path in reversed(self.mounts):
                self.runner.run(["umount", "-R", str(path)], check=False, timeout=90)
            if self.target:
                try:
                    self.target.rmdir()
                except OSError:
                    pass
            self.runner.log.close()
        self.report.emit("complete", 1, "AmogOS 2 Pro is installed. Welcome home.", done=True)

    def _validate_boot_targets(self):
        for item in self.plan.get("bootTargets", []):
            selected = disk_by_path(self.runner, item["path"], inspect=False)
            if fingerprint(selected) != item["fingerprint"]:
                raise InstallError("The custom boot disk changed after review. Review a new installation plan.")

    def _partitions(self, disk):
        r = self.runner
        self.report.emit("partition", .07, "Preparing the partitions you reviewed")
        for step in self.plan["steps"]:
            action = step["action"]
            if action == "label":
                r.run(["wipefs", "--all", "--force", self.plan["disk"]])
                r.run(["parted", "--script", self.plan["disk"], "mklabel", "gpt"])
            elif action == "shrink":
                size = step["size"] - MIB
                if step["fs"] == "ntfs":
                    r.run(["ntfsresize", "--no-action", "--size", str(size), step["path"]], timeout=900)
                    r.run(["ntfsresize", "--size", str(size), step["path"]], input="y\n", timeout=1800)
                    self.report.emit("partition", .1, "Windows will check its resized filesystem at the next boot. Let that check complete.", warning=True)
                elif step["fs"] == "ext4":
                    r.run(["e2fsck", "-f", "-p", step["path"]], allowed=(0, 1), timeout=1800)
                    r.run(["resize2fs", step["path"], f"{size // 1024}K"], timeout=1800)
                else:
                    raise InstallError("This filesystem cannot be resized by the installer.")
                r.run(["sfdisk", "--lock=yes", "--wipe", "never", "--wipe-partitions", "never", "-N", str(step["number"]), self.plan["disk"]], input=f"size={step['size'] // disk['sectorSize']}\n")
            elif action == "create":
                args = ["parted", "--script", "--align", "optimal", self.plan["disk"], "unit", "B", "mkpart", "AmogOS-" + step["role"] if self.plan["table"] == "gpt" else "primary"]
                if step["fs"]:
                    args.append(step["fs"])
                r.run(args + [str(step["start"]) + "B", str(step["start"] + step["size"] - 1) + "B"])
                table = read_table(r, self.plan["disk"])
                created = next((p for p in table.get("partitions", []) if p["start"] * table.get("sectorsize", 512) == step["start"]), None)
                if not created or created["node"] != self._path(step["number"]):
                    raise InstallError("The created partition does not match the reviewed partition plan.")
                if step["role"] in ("esp", "bios"):
                    r.run(["parted", "--script", self.plan["disk"], "set", str(step["number"]), "esp" if step["role"] == "esp" else "bios_grub", "on"])
            elif action == "format":
                r.run(["partprobe", self.plan["disk"]])
                r.run(["udevadm", "settle"], timeout=60)
                if step["fs"] == "ext4":
                    r.run(["mkfs.ext4", "-F", "-L", "AmogOS", step["path"]], timeout=600)
                else:
                    r.run(["mkfs.fat", "-F", "32", "-n", "AMOGOS_EFI", step["path"]])
        r.run(["partprobe", self.plan["disk"]])
        r.run(["udevadm", "settle"], timeout=60)

    def _path(self, number):
        disk = self.plan["disk"]
        return f"{disk}{'p' if disk[-1].isdigit() else ''}{number}"

    def _mount(self, source, target, options=None):
        target = pathlib.Path(target)
        target.mkdir(parents=True, exist_ok=True)
        self.runner.run(["mount", *([] if options is None else ["-o", options]), str(source), str(target)])
        self.mounts.append(target)

    def _copy(self, medium):
        self.report.emit("copy", .17, "Unpacking your AmogOS 2 Pro system")
        def progress(line):
            percent = re.search(r"(\d+)%", line)
            if percent:
                self.report.emit("copy", .17 + .45 * int(percent.group(1)) / 100, "Copying AmogOS 2 Pro")
        self.runner.stream(["nice", "-n", "10", "unsquashfs", "-force", "-processors", "1", "-data-queue", "8", "-frag-queue", "8", "-percentage", "-d", str(self.target), str(medium / "live/filesystem.squashfs")], progress)
        descriptor=os.open(self.target,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
        try:
            os.fchown(descriptor,0,0)
            os.fchmod(descriptor,0o755)
        finally:
            os.close(descriptor)
        self.report.emit("copy", .63, "Your system files are in place")

    def _runtime(self):
        for name in ("dev", "proc", "sys"):
            destination = self.target / name
            destination.mkdir(exist_ok=True)
            self.runner.run(["mount", "--rbind", "/" + name, str(destination)])
            self.runner.run(["mount", "--make-rslave", str(destination)])
            self.mounts.append(destination)
        (self.target / "run").mkdir(exist_ok=True)
        self.runner.run(["mount", "-t", "tmpfs", "-o", "mode=755,nosuid,nodev", "tmpfs", str(self.target / "run")])
        self.mounts.append(self.target / "run")
        (self.target / "run/amogos-install-target").touch()
        resolver = self.target / "etc/resolv.conf"
        if resolver.is_symlink():
            resolver.unlink()
        resolver.write_text(pathlib.Path("/etc/resolv.conf").read_text())
        policy = self.target / "usr/sbin/policy-rc.d"
        policy.write_text("#!/bin/sh\nexit 101\n")
        policy.chmod(0o755)

    def chroot(self, args, **kwargs):
        return self.runner.run(["chroot", str(self.target), *args], **kwargs)

    def write(self, name, text):
        path = self.target / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def _uuid(self, device):
        value = self.runner.run(["blkid", "-s", "UUID", "-o", "value", device]).stdout.strip()
        if not re.fullmatch(r"[A-Za-z0-9-]+", value):
            raise InstallError("The installed filesystem has no valid UUID.")
        return value

    def _configure(self):
        self.report.emit("configure", .66, "Making AmogOS 2 Pro yours")
        a = self.request["account"]
        existing = self.chroot(["getent", "passwd", a["username"]], check=False)
        if existing.returncode == 0 and int(existing.stdout.split(":")[2]) < 1000:
            raise InstallError("This username belongs to a system account.")
        groups = [g for g in ("sudo", "audio", "video", "netdev", "plugdev") if self.chroot(["getent", "group", g], check=False).returncode == 0]
        if existing.returncode:
            self.chroot(["useradd", "--create-home", "--shell", "/bin/bash", "--comment", a["name"], "--groups", ",".join(groups), a["username"]])
        else:
            self.chroot(["usermod", "--comment", a["name"], "--append", "--groups", ",".join(groups), a["username"]])
        self.chroot(["chpasswd"], input=a["username"] + ":" + a["password"] + "\n")
        self.chroot(["passwd", "--lock", "root"])
        if a["username"] != "user":
            live = self.chroot(["getent", "passwd", "user"], check=False)
            if live.returncode == 0 and int(live.stdout.split(":")[2]) == 1000:
                self.chroot(["userdel", "--force", "--remove", "user"])
        for name in ("live", "live-config"):
            (self.target / "etc/sudoers.d" / name).unlink(missing_ok=True)
        self.write("etc/sudoers.d/90-amogos-user", a["username"] + " ALL=(ALL:ALL) ALL\n")
        (self.target / "etc/sudoers.d/90-amogos-user").chmod(0o440)
        for folder in ("etc/skel/Desktop", "home/" + a["username"] + "/Desktop"):
            for name in ("install-system.desktop", "amogos-installer.desktop", "amogos.installer.desktop"):
                shortcut = self.target / folder / name
                if shortcut.is_file() and shortcut.resolve().is_relative_to(self.target.resolve()):
                    shortcut.unlink()
        self.write("usr/share/applications/amogos.installer.desktop", "# Live installer is hidden on the installed system.\n[Desktop Entry]\nType=Application\nName=Install AmogOS 2 Pro\nExec=/usr/bin/amogos-installer\nStartupWMClass=amogos.installer\nNoDisplay=true\n")
        self.write("etc/hostname", a["hostname"] + "\n")
        self.write("etc/hosts", "127.0.0.1 localhost\n127.0.1.1 " + a["hostname"] + "\n::1 localhost ip6-localhost ip6-loopback\n")
        self.write("etc/default/locale", 'LANG="' + self.request["locale"] + '"\n')
        self.write("etc/locale.gen", self.request["locale"] + " UTF-8\n")
        self.chroot(["locale-gen"], timeout=300)
        self.write("etc/timezone", self.request["timezone"] + "\n")
        localtime = self.target / "etc/localtime"
        if localtime.exists() or localtime.is_symlink():
            localtime.unlink()
        localtime.symlink_to("/usr/share/zoneinfo/" + self.request["timezone"])
        self.write("etc/default/keyboard", 'XKBMODEL="pc105"\nXKBLAYOUT="' + self.request["keyboard"] + '"\nXKBVARIANT=""\nXKBOPTIONS=""\n')
        session = "plasma"
        preferred = self.target / "etc/amogos/desktop-session"
        if preferred.is_file():
            value = preferred.read_text().strip()
            if value in ("plasma", "plasmax11") and (value != "plasmax11" or (self.target / "usr/bin/kwin_x11").is_file()):
                session = value
        self.write("etc/sddm.conf", "[Autologin]\nUser=" + (a["username"] if a.get("autoLogin") else "") + "\nSession=" + session + "\n")
        fstab = "UUID=" + self._uuid(self.plan["root"]) + " / ext4 defaults,errors=remount-ro 0 1\n"
        if self.plan["esp"]:
            fstab += "UUID=" + self._uuid(self.plan["esp"]) + " /boot/efi vfat umask=0077 0 2\n"
        self.write("etc/fstab", fstab)
        self.write("etc/crypttab", "")
        self.write("etc/initramfs-tools/conf.d/resume", "RESUME=none\n")
        machine = self.target / "etc/machine-id"
        if machine.is_symlink():
            machine.unlink()
        machine.write_text("")
        for key in (self.target / "etc/ssh").glob("ssh_host_*"):
            if key.is_file():
                key.unlink()
        root_keys = self.target / "root/.ssh/authorized_keys"
        if root_keys.exists():
            root_keys.unlink()
        self.write("etc/apt/sources.list", "deb https://deb.debian.org/debian trixie main contrib non-free non-free-firmware\n"
            "deb https://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware\n"
            "deb https://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware\n")

    def _packages(self):
        try:
            configure_packages(self.runner,self.target,self.report,self.plan["drivers"],self.plan["upgrade"])
        finally:
            (self.target / "usr/sbin/policy-rc.d").unlink(missing_ok=True)

    def _ensure_system_core(self):
        installed=self.chroot(["dpkg-query","-W","-f=${db:Status-Status} ${Version}","amogos-system"],check=False)
        status=installed.stdout.split()
        if installed.returncode==0 and len(status)==2 and status[0]=="installed":
            if self.chroot(["dpkg","--compare-versions",status[1],"ge",SYSTEM_VERSION],check=False).returncode==0:
                return
        package=SYSTEM_PACKAGE
        if not package.is_file():
            raise InstallError('The persistent AmogOS system package is missing from the live installer.')
        temporary=self.target/'var/tmp/amogos-system.deb'
        shutil.copyfile(package,temporary)
        try:
            self.chroot(["dpkg","-i","/var/tmp/amogos-system.deb"],timeout=300)
        finally:
            temporary.unlink(missing_ok=True)

    def _remove_live_tools(self):
        self.report.emit('finish',.97,'Removing live-session installation tools')
        names={'amogos-installer','calamares','calamares-settings-debian'}
        command=['apt-get','-y','--no-auto-remove','purge',*sorted(names)]
        result=self.chroot([command[0],'--simulate',*command[1:]],timeout=120)
        removed={line.split()[1] for line in result.stdout.splitlines() if line.startswith(('Remv ','Purg '))}
        if removed-names:
            raise InstallError('Removing the live installers would remove other applications; refusing.')
        self.chroot(command,timeout=600)
        folders=[self.target/'etc/skel/Desktop',self.target/'home'/self.request['account']['username']/'Desktop']
        for folder in folders:
            for name in ('amogos.installer.desktop','amogos-calamares-fallback.desktop','calamares.desktop','install-debian.desktop'):
                (folder/name).unlink(missing_ok=True)
        (self.target/'usr/share/applications/amogos-calamares-fallback.desktop').unlink(missing_ok=True)

    def _boot(self, medium):
        self.report.emit("bootloader", .88, "Creating your boot menu")
        prepare_kernels(self.runner, self.target, medium)
        if self.plan.get("bootTargets") and not self.plan["esp"]:
            self._validate_boot_targets()
        Bootloader(self.runner, self.target, self.plan, self.report).install()
        self.report.emit("bootloader", .96, "Your boot setup is ready")
