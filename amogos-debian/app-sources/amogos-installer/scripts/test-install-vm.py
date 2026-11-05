# The VM harness installs onto a fresh disposable image and boots it under BIOS and UEFI.
import datetime
import json
import os
import pathlib
import re
import shutil
import socket
import subprocess
import time

W = pathlib.Path(os.environ["AMOGOS_BUILD_DIR"]).resolve(strict=True)
if W == pathlib.Path("/"):
    raise SystemExit("Use a dedicated prepared build workspace.")
RUN = W / "logs" / ("installer-vm-" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
RUN.mkdir()
ISO = W / "output/AmogOS-Chocolatier-Installer-checkpoint002.iso"
DISK = RUN / "disposable-install.qcow2"
subprocess.run(["qemu-img", "create", "-f", "qcow2", str(DISK), "32G"], check=True)
ANSI = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")


def connect(path, process):
    until = time.monotonic() + 30
    while time.monotonic() < until:
        sock = socket.socket(socket.AF_UNIX)
        try:
            sock.connect(str(path))
            return sock
        except (FileNotFoundError, ConnectionRefusedError):
            sock.close()
            if process.poll() is not None:
                raise RuntimeError("QEMU exited before its socket opened")
            time.sleep(.1)
    raise TimeoutError(str(path))


def boot(label, installation=False, efi=False):
    folder = RUN / label
    folder.mkdir()
    qmp_path, serial_path = folder / "qmp.sock", folder / "serial.sock"
    args = ["qemu-system-x86_64", "-machine", "q35,accel=tcg", "-cpu", "max", "-smp", "2", "-m", "2048", "-display", "none", "-vga", "std", "-monitor", "none", "-no-reboot", "-nic", "none",
        "-qmp", f"unix:{qmp_path},server=on,wait=off", "-chardev", f"socket,id=serial0,path={serial_path},server=on,wait=off", "-serial", "chardev:serial0",
        "-drive", f"if=none,id=target,format=qcow2,file={DISK}" + ("" if installation else ",snapshot=on"),
        "-device", "virtio-blk-pci,drive=target,serial=AMOGOS-INSTALL-TEST"]
    if installation:
        args += ["-kernel", str(W/"iso-tree/live/vmlinuz"), "-initrd", str(W/"iso-tree/live/initrd"), "-append", "boot=live init=/bin/bash console=tty0 console=ttyS0,115200n8",
            "-drive", f"file={ISO},media=cdrom,format=raw,readonly=on",
            "-virtfs", f"local,path={W/'apps/installer'},mount_tag=installersrc,security_model=none,readonly=on"]
    elif efi:
        shutil.copyfile("/usr/share/OVMF/OVMF_VARS_4M.fd", folder/"vars.fd")
        args += ["-drive", "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd", "-drive", f"if=pflash,format=raw,file={folder/'vars.fd'}"]
    (folder/"command.json").write_text(json.dumps(args,indent=2))
    start=time.monotonic()
    result=dict(test=label,passed=False)
    with (folder/"qemu.log").open("wb") as stderr, (folder/"serial.log").open("wb",buffering=0) as log:
        process=subprocess.Popen(args,stdin=subprocess.DEVNULL,stdout=stderr,stderr=stderr)
        serial=qmp=qf=None
        try:
            serial=connect(serial_path,process);serial.settimeout(1)
            qmp=connect(qmp_path,process);qmp.settimeout(20);qf=qmp.makefile("rb");qf.readline()
            def command(name,arguments=None):
                request=dict(execute=name)
                if arguments: request["arguments"]=arguments
                qmp.sendall(json.dumps(request).encode()+b"\n")
                while True:
                    response=json.loads(qf.readline())
                    if "return" in response: return response["return"]
                    if "error" in response: raise RuntimeError(str(response["error"]))
            command("qmp_capabilities")
            data=b"";sent=False;deadline=start+(1500 if installation else 360)
            while time.monotonic()<deadline:
                try: chunk=serial.recv(65536)
                except socket.timeout: chunk=b""
                if chunk:log.write(chunk);data=(data+chunk)[-200000:]
                clean=ANSI.sub(b"",data)
                if installation and not sent and re.search(rb"(?:root@[^\n]*# |bash-[0-9.]+# )",clean):
                    line="set -e; /usr/lib/systemd/systemd-udevd --daemon || true; mkdir -p /mnt/installer-src; modprobe 9pnet_virtio; mount -t 9p -o ro,trans=virtio,version=9p2000.L installersrc /mnt/installer-src; python3 /mnt/installer-src/scripts/guest-install-check.py; echo GUEST_SCRIPT_RETURNED"
                    serial.sendall(line.encode()+b"\n");sent=True
                if installation and b"INSTALL_CHECK_PASSED" in clean:
                    result["passed"]=True;result["milestone"]="Installed system, account, fstab, kernel, initramfs, and both bootloaders validated";break
                if b"INSTALL_CHECK_FAILED" in clean or b"Kernel panic" in clean:
                    raise RuntimeError("Guest installation or kernel failed")
                if not installation and re.search(rb"Started [^\n]*Display Manager|[^\n]*login:",clean):
                    result["passed"]=True;result["milestone"]="Installed disk booted without the live ISO";break
                if process.poll() is not None: raise RuntimeError("QEMU exited during the test")
            if not result["passed"]:result["error"]="Timed out waiting for the guest"
            command("screendump",dict(filename=str(folder/"screen.ppm")))
            command("quit");process.wait(timeout=15)
        except Exception as error:
            result["error"]=str(error)
        finally:
            if serial:serial.close()
            if qf:qf.close()
            if qmp:qmp.close()
            if process.poll() is None:
                process.terminate()
                try:process.wait(timeout=10)
                except subprocess.TimeoutExpired:process.kill();process.wait()
    result["seconds"]=round(time.monotonic()-start,1)
    (folder/"result.json").write_text(json.dumps(result,indent=2))
    print(json.dumps(result),flush=True)
    return result


results=[boot("install",installation=True)]
if results[0]["passed"]:
    results += [boot("installed-bios"),boot("installed-uefi",efi=True)]
(RUN/"results.json").write_text(json.dumps(results,indent=2))
(W/"logs/latest-installer-vm.txt").write_text(str(RUN)+"\n")
raise SystemExit(0 if len(results)==3 and all(r["passed"] for r in results) else 1)
