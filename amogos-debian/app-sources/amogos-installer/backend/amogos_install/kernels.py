# Preserve upgraded target kernels and generate an installed-system initramfs for each usable kernel.
import pathlib
import platform
import shutil
from .runtime import InstallError


def prepare_kernels(runner, target, medium):
    target, medium = pathlib.Path(target), pathlib.Path(medium)
    boot = target / "boot"
    boot.mkdir(exist_ok=True)
    kernels = [p for p in boot.glob("vmlinuz-*") if p.is_file() and (target / "lib/modules" / p.name.removeprefix("vmlinuz-")).is_dir()]
    if not kernels:
        version = platform.release()
        if not (target / "lib/modules" / version).is_dir():
            raise InstallError("No installed kernel has matching modules. See the installation log before restarting.")
        kernel = boot / ("vmlinuz-" + version)
        if not kernel.exists():
            shutil.copyfile(medium / "live/vmlinuz", kernel)
        kernels = [kernel]
    runner.run(["chroot", str(target), "plymouth-set-default-theme", "amogos2pro"], timeout=60)
    for kernel in kernels:
        version = kernel.name.removeprefix("vmlinuz-")
        action = "-u" if (boot / ("initrd.img-" + version)).is_file() else "-c"
        runner.run(["chroot", str(target), "update-initramfs", action, "-k", version], timeout=1800)
    return [p.name.removeprefix("vmlinuz-") for p in kernels]
