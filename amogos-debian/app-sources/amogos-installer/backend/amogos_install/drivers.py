# Hardware recommendations use PCI and USB identities with Debian firmware and NVIDIA detection.
import pathlib
import re
from .runtime import InstallError
from .offline_drivers import verified_cache

BROADCOM_STA_IDS = frozenset("4311 4312 4313 4315 4727 4328 4329 432a 432b 432c 432d 4365 4353 4357 4358 4359 4331 43a0".split())


def hardware_records(runner):
    records = []
    for bus in ("pci", "usb"):
        for directory in pathlib.Path(f"/sys/bus/{bus}/devices").glob("*"):
            def value(name):
                try:
                    return (directory / name).read_text().strip().lower().replace("0x", "")
                except OSError:
                    return ""
            vendor, device = value("vendor") or value("idVendor"), value("device") or value("idProduct")
            kind = value("class")
            modalias = value("modalias")
            modules = runner.run(["modprobe", "--resolve-alias", modalias], check=False).stdout.split() if modalias else []
            records.append((vendor, device, kind, modules))
    return records


def recommendations(runner):
    devices = []
    records = hardware_records(runner)
    nvidia = any(v == "10de" and k.startswith("03") for v, _, k, _ in records)
    if nvidia:
        package = runner.run(["nvidia-detect"], check=False).stdout
        found = re.search(r"(?m)^\s+(nvidia(?:-tesla-[a-z0-9-]+)?-driver)\s*$", package)
        packages = ["linux-image-amd64", "linux-headers-amd64", found.group(1)] if found else ["firmware-nvidia-graphics"]
        if found:
            packages.append(found.group(1).removesuffix("-driver") + "-driver-libs:i386")
        devices.append(dict(device="NVIDIA graphics", packages=packages, note="Recommended by Debian nvidia-detect" if found else "Open-source Nouveau firmware; no supported proprietary package was identified"))
    mappings = [
        ("8086", "03", "Intel graphics", ["firmware-intel-graphics"]),
        ("1002", "03", "AMD graphics", ["firmware-amd-graphics"]),
        ("8086", "02", "Intel network hardware", ["firmware-iwlwifi"]),
        ("10ec", "02", "Realtek network hardware", ["firmware-realtek"]),
        ("168c", "02", "Qualcomm Atheros Wi-Fi", ["firmware-atheros"]),
        ("17cb", "02", "Qualcomm Wi-Fi", ["firmware-atheros"]),
        ("14e4", "02", "Broadcom network hardware", ["firmware-brcm80211"]),
    ]
    for vendor, kind, label, packages in mappings:
        if any(v == vendor and k.startswith(kind) for v, _, k, _ in records):
            devices.append(dict(device=label, packages=packages, note="Firmware selected from the device vendor and class"))
    if any(v == "14e4" and d in BROADCOM_STA_IDS and k.startswith("02") for v, d, k, _ in records):
        devices.append(dict(device="Broadcom STA Wi-Fi", packages=["linux-image-amd64", "linux-headers-amd64", "broadcom-sta-dkms"], note="PCI identity listed in the bundled Broadcom driver documentation"))
    for vendor, _, _, modules in records:
        names = " ".join(modules)
        if vendor in ("0bda", "0b05") and re.search(r"rtl|rtw", names):
            devices.append(dict(device="Realtek USB Wi-Fi", packages=["firmware-realtek"], note="USB wireless module detected"))
        elif re.search(r"ath[0-9a-z_]*", names):
            devices.append(dict(device="Qualcomm wireless firmware", packages=["firmware-atheros"], note="Wireless module detected"))
        elif re.search(r"brcm|brcmfmac", names):
            devices.append(dict(device="Broadcom wireless firmware", packages=["firmware-brcm80211"], note="Wireless module detected"))
        elif "mt76" in names or vendor == "0e8d":
            devices.append(dict(device="MediaTek wireless firmware", packages=["firmware-mediatek"], note="Wireless module detected"))
    seen = set()
    unique = []
    for d in devices:
        key = tuple(d["packages"])
        if key not in seen:
            unique.append(d)
            seen.add(key)
    return unique


def install_drivers(runner, target, report, enabled, network):
    if not enabled:
        return
    devices = recommendations(runner)
    packages = sorted({p for d in devices for p in d["packages"]})
    if not packages:
        return
    cache = verified_cache(target) if not network else None
    if not network and cache is None:
        report.emit("drivers", .82, "The bundled kernel drivers and firmware are available. This image has no additional offline driver archive.", warning=True)
        return
    valid = []
    for p in packages:
        if not re.fullmatch(r"[a-z0-9][a-z0-9+.-]+(?::(?:amd64|i386))?", p):
            raise InstallError("An invalid driver package was detected.")
        result = runner.run(["chroot", target, "apt-cache", "show", p], check=False)
        if result.returncode == 0:
            valid.append(p)
    if valid:
        report.emit("drivers", .80, "Installing recommended hardware support" + (" from the offline bundle" if cache else ""))
        options = ["--no-download", "-o", "Dir::Cache::archives=" + cache] if cache else ["-o", "Acquire::Retries=3"]
        try:
            runner.stream(["chroot", str(target), "apt-get", "install", "-y", "--no-remove", "--no-install-recommends", "-o", "Dpkg::Options::=--force-confold", *options, *valid])
        except InstallError as error:
            runner.run(["chroot", str(target), "dpkg", "--configure", "-a"], check=False, timeout=1800)
            raise InstallError("Recommended driver installation did not finish. See the installation log before restarting. " + str(error)) from error
        if "broadcom-sta-dkms" in valid:
            blacklist = pathlib.Path(target) / "etc/modprobe.d/broadcom-sta-dkms.conf"
            if blacklist.is_file():
                blacklist.write_text("\n".join(line for line in blacklist.read_text().splitlines() if line.strip() != "blacklist b44") + "\n")
        runner.run(["chroot", str(target), "apt-get", "check"], timeout=180)
        audit = runner.run(["chroot", str(target), "dpkg", "--audit"], timeout=180)
        if audit.stdout.strip():
            raise InstallError("Driver packages still need configuration. " + audit.stdout.strip())
