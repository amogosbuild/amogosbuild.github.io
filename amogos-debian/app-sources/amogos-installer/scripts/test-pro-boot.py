# The Pro VM harness verifies a preserved external ESP and both installed bootloader choices.
import datetime
import json
import pathlib
import re
import shutil
import socket
import subprocess
import sys
import time
from PIL import Image

W = pathlib.Path("/srv/chocolatier")
ISO = pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else W/"output/AmogOS-2-Pro-Installer-checkpoint005.iso"
assert ISO.is_file()
RUN = W/"logs"/("pro-boot-"+datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
RUN.mkdir()
DISKS = [RUN/"disposable-root.qcow2", RUN/"disposable-boot.qcow2"]
for disk, size in zip(DISKS, ["32G", "2G"]):
    subprocess.run(["qemu-img", "create", "-f", "qcow2", str(disk), size], check=True)
VARS = RUN/"vars.fd"
shutil.copyfile("/usr/share/OVMF/OVMF_VARS_4M.fd", VARS)
ANSI = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")


def connect(path, process):
    deadline = time.monotonic()+30
    while time.monotonic()<deadline:
        sock = socket.socket(socket.AF_UNIX)
        try:
            sock.connect(str(path))
            return sock
        except (FileNotFoundError, ConnectionRefusedError):
            sock.close()
            if process.poll() is not None:
                raise RuntimeError("QEMU exited before opening its socket")
            time.sleep(.1)
    raise TimeoutError(str(path))


def boot(label, phase=None, efi=True):
    maintenance = phase in ("install", "switch")
    if phase == "switch":
        shutil.copyfile("/usr/share/OVMF/OVMF_VARS_4M.fd", VARS)
    folder = RUN/label
    folder.mkdir()
    qmp_path, serial_path = folder/"qmp.sock", folder/"serial.sock"
    args = ["qemu-system-x86_64", "-machine", "q35,accel=tcg", "-cpu", "max", "-smp", "2", "-m", "2048", "-display", "none", "-vga", "std", "-monitor", "none", "-no-reboot", "-nic", "none", "-qmp", f"unix:{qmp_path},server=on,wait=off", "-chardev", f"socket,id=serial0,path={serial_path},server=on,wait=off", "-serial", "chardev:serial0"]
    for i, (disk, serial) in enumerate(zip(DISKS, ["AMOGOS-PRO-ROOT-TEST", "AMOGOS-PRO-BOOT-TEST"])):
        args += ["-drive", f"if=none,id=disk{i},format=qcow2,file={disk}"+("" if maintenance else ",snapshot=on"), "-device", f"virtio-blk-pci,drive=disk{i},serial={serial}"+("" if phase else f",bootindex={2-i}")]
    if efi:
        args += ["-drive", "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd", "-drive", f"if=pflash,format=raw,file={VARS}"]
    if phase:
        cmdline = "boot=live console=tty0 console=ttyS0,115200n8 " + ("init=/bin/bash" if maintenance else "quiet splash plymouth.ignore-serial-consoles plymouth.debug")
        args += ["-kernel", str(W/"iso-tree/live/vmlinuz"), "-initrd", str(W/"iso-tree/live/initrd"), "-append", cmdline, "-drive", f"file={ISO},media=cdrom,format=raw,readonly=on", "-virtfs", f"local,path={W/'apps/installer'},mount_tag=installersrc,security_model=none,readonly=on"]
    (folder/"command.json").write_text(json.dumps(args, indent=2))
    start = time.monotonic()
    result = dict(test=label, passed=False)
    with (folder/"qemu.log").open("wb") as stderr, (folder/"serial.log").open("wb", buffering=0) as log:
        process = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=stderr, stderr=stderr)
        serial = qmp = qf = None
        try:
            serial = connect(serial_path, process); serial.settimeout(.5)
            qmp = connect(qmp_path, process); qmp.settimeout(20); qf=qmp.makefile("rb"); qf.readline()
            def command(name, arguments=None):
                request = dict(execute=name)
                if arguments:
                    request["arguments"] = arguments
                qmp.sendall(json.dumps(request).encode()+b"\n")
                while True:
                    reply = json.loads(qf.readline())
                    if "return" in reply:
                        return reply["return"]
                    if "error" in reply:
                        raise RuntimeError(str(reply["error"]))
            def capture(name):
                ppm = folder/"temporary.ppm"
                command("screendump", dict(filename=str(ppm)))
                with Image.open(ppm) as image:
                    image.save(folder/(name+".png"))
                ppm.unlink()
            command("qmp_capabilities")
            data=b""; sent=False; next_capture=12
            deadline=start+(1500 if phase=="install" else 900 if phase=="switch" else 360)
            while time.monotonic()<deadline:
                try:
                    chunk=serial.recv(65536)
                except socket.timeout:
                    chunk=b""
                if chunk:
                    log.write(chunk); data=(data+chunk)[-200000:]
                clean=ANSI.sub(b"", data)
                elapsed=time.monotonic()-start
                if not maintenance and elapsed>=next_capture:
                    capture(f"boot-{int(elapsed):03d}")
                    next_capture=elapsed+4
                if maintenance and not sent and re.search(rb"(?:root@[^\n]*# |bash-[0-9.]+# )",clean):
                    line="set -e; /usr/lib/systemd/systemd-udevd --daemon || true; mkdir -p /mnt/installer-src; modprobe 9pnet_virtio; mount -t 9p -o ro,trans=virtio,version=9p2000.L installersrc /mnt/installer-src; python3 /mnt/installer-src/scripts/guest-pro-boot-check.py"+(" --systemd" if phase=="switch" else "")+"; echo GUEST_SCRIPT_RETURNED"
                    serial.sendall(line.encode()+b"\n"); sent=True
                if maintenance and b"PRO_CHECK_PASSED" in clean:
                    result["passed"]=True; break
                if b"PRO_CHECK_FAILED" in clean or b"Kernel panic" in clean or (maintenance and b"Traceback (most recent call last)" in clean):
                    raise RuntimeError("Guest test failed; inspect serial.log")
                if not maintenance and re.search(rb"Started [^\n]*Display Manager|[^\n]*login:", clean):
                    result["passed"]=True; break
                if process.poll() is not None:
                    raise RuntimeError("QEMU exited during the test")
            if not result["passed"]:
                result["error"]="Timed out waiting for the guest"
            capture("screen")
            command("quit"); process.wait(timeout=15)
        except Exception as error:
            result["error"]=str(error)
        finally:
            if serial: serial.close()
            if qf: qf.close()
            if qmp: qmp.close()
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()
    result["seconds"]=round(time.monotonic()-start,1)
    (folder/"result.json").write_text(json.dumps(result,indent=2))
    print(json.dumps(result),flush=True)
    return result


(W/"logs/latest-pro-boot.txt").write_text(str(RUN)+"\n")
results=[boot("live-plymouth",phase="live")]
results.append(boot("install-external-grub",phase="install"))
if results[-1]["passed"]:
    results.append(boot("installed-grub-uefi"))
    results.append(boot("installed-grub-bios",efi=False))
    results.append(boot("switch-systemd-boot",phase="switch"))
    if results[-1]["passed"]:
        results.append(boot("installed-systemd-uefi"))
(RUN/"results.json").write_text(json.dumps(results,indent=2))
raise SystemExit(0 if len(results)==6 and all(r["passed"] for r in results) else 1)
