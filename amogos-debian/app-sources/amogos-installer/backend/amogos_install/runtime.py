# Command execution, progress reporting, and live-session checks share one constrained runtime.
import ctypes
import datetime
import json
import os
import pathlib
import subprocess
import sys
import time


class InstallError(RuntimeError):
    pass


class Runner:
    def __init__(self, log=None):
        self.log = log
        self.env = dict(os.environ, PATH="/usr/sbin:/usr/bin:/sbin:/bin", LC_ALL="C", DEBIAN_FRONTEND="noninteractive", MAKEFLAGS="-j1", CMAKE_BUILD_PARALLEL_LEVEL="1", OMP_NUM_THREADS="1", TMPDIR="/var/tmp")

    def run(self, args, *, check=True, input=None, timeout=120, allowed=(0,)):
        result = subprocess.run([str(a) for a in args], input=input, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=self.env, timeout=timeout)
        if self.log:
            self.log.write("$ " + " ".join(str(a) for a in args) + "\n" + result.stdout + "\n")
            self.log.flush()
        if check and result.returncode not in allowed:
            raise InstallError(f"{args[0]} failed ({result.returncode}): {result.stdout[-1800:]}")
        return result

    def stream(self, args, callback=None):
        if self.log:
            self.log.write("$ " + " ".join(str(a) for a in args) + "\n")
        args = [str(a) for a in args]
        read_fd = write_fd = None
        try:
            if any("{status_fd}" in a for a in args):
                read_fd, write_fd = os.pipe()
                args = [a.replace("{status_fd}", str(write_fd)) for a in args]
                process = subprocess.Popen(args, stdout=write_fd, stderr=subprocess.STDOUT, pass_fds=(write_fd,), env=self.env)
                os.close(write_fd)
                write_fd = None
                output = os.fdopen(read_fd, "r", encoding="utf-8", errors="replace")
                read_fd = None
            else:
                process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", env=self.env, bufsize=1)
                output = process.stdout
        finally:
            for descriptor in (read_fd, write_fd):
                if descriptor is not None:
                    os.close(descriptor)
        tail = ""
        try:
            with output:
                for line in output:
                    tail = (tail + line)[-2000:]
                    if self.log:
                        self.log.write(line)
                    if callback:
                        callback(line)
            process.wait()
        except BaseException:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            raise
        if self.log:
            self.log.flush()
        if process.returncode:
            raise InstallError(f"{args[0]} failed ({process.returncode}): {tail}")


class Reporter:
    def __init__(self):
        self.progress = 0.0
        self._last_stage = None
        self._last_emit = 0.0

    def emit(self, stage, progress, message, **flags):
        self.progress = max(self.progress, min(1.0, progress))
        now = time.monotonic()
        if stage == self._last_stage and not flags and now - self._last_emit < .25:
            return
        self._last_stage, self._last_emit = stage, now
        event = dict(stage=stage, progress=self.progress, message=message, **flags)
        try:
            print(json.dumps(event), flush=True)
        except BrokenPipeError:
            sys.stdout = open(os.devnull, "w")


def live_medium():
    for name in ("/run/live/medium", "/lib/live/mount/medium", "/cdrom"):
        path = pathlib.Path(name)
        if (path / "live/filesystem.squashfs").is_file():
            return path.resolve()
    return None


def require_live(runner):
    medium = live_medium()
    rootfs = runner.run(["findmnt", "-n", "-o", "FSTYPE", "/"]).stdout.strip()
    if os.geteuid() != 0 or medium is None or rootfs not in ("overlay", "aufs"):
        raise InstallError("Disk installation is only allowed inside the live AmogOS session. The VPS and ordinary installed systems are protected.")
    return medium


def private_mounts(runner):
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.unshare(0x00020000) != 0:
        raise InstallError("Could not create a private mount namespace.")
    runner.run(["mount", "--make-rprivate", "/"])


def log_directory():
    root = pathlib.Path("/var/log/amogos-installer")
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = root / stamp
    path.mkdir(mode=0o700, exist_ok=False)
    return path
