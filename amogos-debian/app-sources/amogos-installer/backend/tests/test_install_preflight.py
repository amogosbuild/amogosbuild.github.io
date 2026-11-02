# Disk preparation must remain unreachable until online repository preflight has succeeded.
import pathlib
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_install.runtime import InstallError
from test_package_updates import Recorder
if sys.platform == "linux":
    from amogos_install import installer


@unittest.skipUnless(sys.platform == "linux", "Full installer runtime requires Linux")
class PreflightTests(unittest.TestCase):
    def run_case(self, failed):
        events = []
        def preflight(*args):
            events.append("repositories")
            if failed:
                raise InstallError("Repository preflight failed")
        def partitions(*args):
            events.append("partitions")
            raise InstallError("Stop before any disk writes")
        with tempfile.TemporaryDirectory() as directory:
            folder = pathlib.Path(directory)
            target = folder / "target"
            target.mkdir()
            plan = dict(disk="/dev/test", confirmation="test", fingerprint="same", steps=[], upgrade=True)
            report = Recorder()
            instance = installer.Installer(plan, dict(confirmation="test"), report)
            instance.runner = report
            with patch.object(installer, "require_live", return_value=folder), patch.object(installer, "validate_settings"), patch.object(installer, "disk_by_path", return_value=dict(path="/dev/test")), patch.object(installer, "fingerprint", return_value="same"), patch.object(installer, "log_directory", return_value=folder), patch.object(installer, "prepare_online", side_effect=preflight), patch.object(installer, "private_mounts", side_effect=lambda runner:events.append("mount namespace")), patch.object(installer.tempfile, "mkdtemp", return_value=str(target)), patch.object(instance, "_validate_boot_targets"), patch.object(instance, "_partitions", side_effect=partitions):
                with self.assertRaises(InstallError):
                    instance.run()
            self.assertTrue(instance.runner.log.closed)
        return events

    def test_failed_repository_preflight_never_reaches_partitioning(self):
        self.assertEqual(self.run_case(True), ["repositories"])

    def test_preflight_precedes_mount_and_partition_preparation(self):
        self.assertEqual(self.run_case(False), ["repositories", "mount namespace", "partitions"])


if __name__ == "__main__":
    unittest.main()
