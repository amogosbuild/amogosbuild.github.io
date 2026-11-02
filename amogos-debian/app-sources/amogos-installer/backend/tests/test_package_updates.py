# Regression tests reject incomplete online upgrades and exercise offline driver archives and kernel preservation.
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_install import drivers, kernels, package_updates as updates
from amogos_install.offline_drivers import verified_cache
from amogos_install.runtime import InstallError


def snapshot(version="1", pending=None, blocked=None):
    return dict(installed={"example:amd64": version}, pending=pending or [], broken=[], removals=[], protectedRemovals=blocked or [])


class Recorder:
    def __init__(self, states=None, failure=None, audit=""):
        self.states = list(states or [])
        self.failure, self.audit = failure, audit
        self.commands, self.events = [], []

    def run(self, args, **kwargs):
        self.commands.append(args)
        if self.failure == "refresh" and args[-1] == "update":
            raise InstallError("One repository is unavailable")
        if "python3" in args:
            return SimpleNamespace(stdout=json.dumps(self.states.pop(0)), returncode=0)
        return SimpleNamespace(stdout=self.audit if "--audit" in args else "", returncode=0)

    def stream(self, args, callback=None):
        self.commands.append(args)
        if self.failure == "upgrade":
            raise InstallError("Download interrupted")
        if callback:
            callback("pmstatus:dpkg:75:Configuring packages")

    def emit(self, *args, **kwargs):
        self.events.append((args, kwargs))


def archive_fixture(target):
    cache = pathlib.Path(target) / "usr/share/amogos/offline-drivers"
    (cache / "archives").mkdir(parents=True)
    package = cache / "archives/example.deb"
    package.write_bytes(b"package archive fixture")
    manifest = dict(schema=1, packages=[dict(file=package.name, sha256=hashlib.sha256(package.read_bytes()).hexdigest(), bytes=package.stat().st_size)])
    (cache / "manifest.json").write_text(json.dumps(manifest))
    return package


class OnlineUpdateTests(unittest.TestCase):
    def test_refresh_requires_every_repository_and_stops_preflight(self):
        runner = Recorder(failure="refresh")
        with self.assertRaisesRegex(InstallError, "No drive changes have started"):
            updates.prepare_online(runner, runner)
        self.assertIn("APT::Update::Error-Mode=any", runner.commands[0])
        self.assertFalse(any("dist-upgrade" in c for c in runner.commands))

    def test_full_upgrade_records_actual_updated_versions(self):
        runner = Recorder([snapshot("1"), snapshot("2")])
        with tempfile.TemporaryDirectory() as target:
            updates.full_upgrade(runner, target, runner)
            result = json.loads((pathlib.Path(target) / "var/log/amogos-installer/package-updates.json").read_text())
        self.assertTrue(result["completed"])
        self.assertEqual(result["upgraded"], [dict(id="example:amd64", fromVersion="1", version="2")])
        self.assertTrue(any("dist-upgrade" in c for c in runner.commands))
        self.assertFalse(any("upgrade" in c for c in runner.commands))

    def test_preflight_authenticates_releases_without_persisting_live_ram_caches(self):
        runner = Recorder()
        updates.prepare_online(runner, runner)
        command = runner.commands[0]
        lists = next(option.removeprefix("Dir::State::lists=") for option in command if option.startswith("Dir::State::lists="))
        self.assertFalse(pathlib.Path(lists).exists())
        self.assertIn("Dir::Cache::pkgcache=", command)
        self.assertIn("Dir::Cache::srcpkgcache=", command)
        self.assertIn("Acquire::IndexTargets::deb::Packages::DefaultEnabled=false", command)
        self.assertIn("APT::Update::Error-Mode=any", command)

    def test_held_packages_and_unconfigured_packages_are_failures(self):
        for pending, audit in [([dict(id="held:amd64", installed="1", candidate="2")], ""), ([], "package needs configuration")]:
            runner = Recorder([snapshot(), snapshot(pending=pending)], audit=audit)
            with tempfile.TemporaryDirectory() as target:
                with self.assertRaisesRegex(InstallError, "pending or unfinished"):
                    updates.full_upgrade(runner, target, runner)
                result = json.loads((pathlib.Path(target) / "var/log/amogos-installer/package-updates.json").read_text())
                self.assertFalse(result["completed"])

    def test_required_desktop_packages_cannot_be_removed(self):
        runner = Recorder([snapshot(blocked=["amogos-store:amd64"])])
        with tempfile.TemporaryDirectory() as target:
            with self.assertRaisesRegex(InstallError, "remove required"):
                updates.full_upgrade(runner, target, runner)
        self.assertFalse(any("dist-upgrade" in c for c in runner.commands))

    def test_failed_upgrade_is_never_reported_as_complete(self):
        runner = Recorder([snapshot()], failure="upgrade")
        with tempfile.TemporaryDirectory() as target:
            with self.assertRaisesRegex(InstallError, "has not been marked up to date"):
                updates.full_upgrade(runner, target, runner)
            result = json.loads((pathlib.Path(target) / "var/log/amogos-installer/package-updates.json").read_text())
            self.assertFalse(result["completed"])
        self.assertTrue(any("--configure" in c for c in runner.commands))

    def test_recovered_upgrade_must_retry_and_verify_actual_final_state(self):
        for pending in ([], [dict(id="still-old:amd64", installed="1", candidate="2")]):
            runner = Recorder([snapshot("1"), snapshot("2", pending=pending)])
            normal_stream = runner.stream
            attempts = []
            def stream(args, callback=None):
                attempts.append(args)
                if len(attempts) == 1:
                    raise InstallError("Maintainer script output failed")
                return normal_stream(args, callback)
            runner.stream = stream
            with tempfile.TemporaryDirectory() as target:
                if pending:
                    with self.assertRaisesRegex(InstallError, "pending or unfinished"):
                        updates.full_upgrade(runner, target, runner)
                else:
                    updates.full_upgrade(runner, target, runner)
                result = json.loads((pathlib.Path(target) / "var/log/amogos-installer/package-updates.json").read_text())
            self.assertEqual(result["completed"], not pending)
            self.assertTrue(result["recoveryAttempted"])
            self.assertEqual(len(attempts), 2)
            self.assertTrue(any("--configure" in c for c in runner.commands))

    def test_failed_configuration_repair_cannot_continue_to_boot(self):
        runner = Recorder([snapshot()], failure="upgrade")
        original = runner.run
        def run(args, **kwargs):
            if "--configure" in args:
                raise InstallError("Configuration still broken")
            return original(args, **kwargs)
        runner.run = run
        with tempfile.TemporaryDirectory() as target:
            with self.assertRaisesRegex(InstallError, "Configuration still broken"):
                updates.full_upgrade(runner, target, runner)
            result = json.loads((pathlib.Path(target) / "var/log/amogos-installer/package-updates.json").read_text())
        self.assertFalse(result["completed"])


class OfflineHardwareTests(unittest.TestCase):
    def test_nvidia_recommendation_keeps_matching_32_bit_driver_branch(self):
        for package in ("nvidia-driver", "nvidia-tesla-535-driver"):
            runner = Recorder()
            runner.run = lambda args, **kwargs: SimpleNamespace(stdout="Install:\n    " + package + "\n", returncode=0)
            with patch.object(drivers, "hardware_records", return_value=[("10de", "2684", "030000", [])]):
                found = drivers.recommendations(runner)
            self.assertIn(package.removesuffix("-driver") + "-driver-libs:i386", found[0]["packages"])

    def test_corrupt_and_escaped_driver_archives_are_rejected(self):
        with tempfile.TemporaryDirectory() as target:
            package = archive_fixture(target)
            self.assertTrue(verified_cache(target).endswith("/archives/"))
            package.write_bytes(b"corrupted")
            with self.assertRaisesRegex(InstallError, "damaged"):
                verified_cache(target)
            manifest = package.parent.parent / "manifest.json"
            value = json.loads(manifest.read_text())
            value["packages"][0]["file"] = "../../../../example.deb"
            manifest.write_text(json.dumps(value))
            with self.assertRaisesRegex(InstallError, "archive path"):
                verified_cache(target)

    def test_offline_nvidia_install_includes_steam_libraries_without_downloads(self):
        runner = Recorder()
        devices = [dict(packages=["nvidia-driver", "nvidia-driver-libs:i386"])]
        with tempfile.TemporaryDirectory() as target, patch.object(drivers, "recommendations", return_value=devices):
            archive_fixture(target)
            drivers.install_drivers(runner, target, runner, True, False)
        command = next(c for c in runner.commands if "install" in c)
        self.assertIn("--no-download", command)
        self.assertIn("nvidia-driver-libs:i386", command)
        self.assertIn("--no-remove", command)

    def test_proprietary_broadcom_selection_uses_supported_pci_id(self):
        for device, expected in [("4365", True), ("ffff", False)]:
            with patch.object(drivers, "hardware_records", return_value=[("14e4", device, "028000", [])]):
                found = drivers.recommendations(Recorder())
            self.assertEqual(any("broadcom-sta-dkms" in d["packages"] for d in found), expected)

    def test_upgraded_kernel_and_initramfs_are_not_replaced_by_live_media(self):
        runner = Recorder()
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory)
            (target / "boot").mkdir()
            version = "6.12.113+deb13-amd64"
            (target / "lib/modules" / version).mkdir(parents=True)
            kernel = target / "boot" / ("vmlinuz-" + version)
            initrd = target / "boot" / ("initrd.img-" + version)
            kernel.write_bytes(b"upgraded kernel")
            initrd.write_bytes(b"target initramfs")
            self.assertEqual(kernels.prepare_kernels(runner, target, target / "nonexistent-medium"), [version])
            self.assertEqual(kernel.read_bytes(), b"upgraded kernel")
            self.assertEqual(initrd.read_bytes(), b"target initramfs")
            self.assertIn("-u", runner.commands[-1])
            initrd.unlink()
            kernels.prepare_kernels(runner, target, target)
            self.assertIn("-c", runner.commands[-1])

    def test_no_kernel_with_matching_modules_is_rejected(self):
        with tempfile.TemporaryDirectory() as target:
            with self.assertRaisesRegex(InstallError, "matching modules"):
                kernels.prepare_kernels(Recorder(), target, target)


if __name__ == "__main__":
    unittest.main()
