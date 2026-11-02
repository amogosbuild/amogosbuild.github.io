# Exercise real dpkg lifecycle scripts inside a minimal disposable chroot without touching the host OS.
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "scripts"))
from archive import ROOT, build_package, place_package


class UpdaterLifecycle(unittest.TestCase):
    def test_changed_script_requires_a_version_bump(self):
        with tempfile.TemporaryDirectory(prefix="amogos-version-test-") as temporary:
            temporary = pathlib.Path(temporary)
            package = build_package(ROOT / "packages/amogos-update", temporary / "packages")
            place_package(package, root=temporary / "repository")
            changed = build_package(ROOT / "packages/amogos-update", temporary / "packages", payload="#!/bin/sh\nprintf changed\n")
            with self.assertRaisesRegex(ValueError, "version bump"):
                place_package(changed, root=temporary / "repository")

    def test_install_upgrade_retry_downgrade_and_purge(self):
        self.assertEqual(os.geteuid(), 0, "Use sudo: this test creates a disposable chroot")
        with tempfile.TemporaryDirectory(prefix="amogos-updater-test-") as temporary:
            temporary = pathlib.Path(temporary)
            root, packages = temporary / "root", temporary / "packages"
            root.mkdir()
            def copy_binary(source, destination=None):
                source = pathlib.Path(source)
                destination = root / str(destination or source).lstrip("/")
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source.resolve(), destination)
                libraries = subprocess.check_output(["ldd", str(source)], text=True)
                for library in set(re.findall(r"(/[A-Za-z0-9_+./-]+)", libraries)):
                    origin = pathlib.Path(library)
                    if origin.is_file():
                        target = root / library.lstrip("/")
                        target.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(origin.resolve(), target)
            copy_binary(shutil.which("sh"), "/bin/sh")
            for binary in ("dpkg", "install", "cat", "mktemp", "chmod", "mv", "rm", "rmdir"):
                copy_binary(shutil.which(binary), "/usr/bin/" + binary)
            (root / "var/lib/dpkg").mkdir(parents=True)
            (root / "var/log").mkdir(parents=True)
            status = "".join("Package: " + name + "\nStatus: install ok installed\nArchitecture: all\nVersion: 9999\nMaintainer: Test\nDescription: Disposable test fixture\n\n" for name in ("dash", "coreutils", "dpkg", "python3", "python3-apt", "amogos-system", "amogos-store", "qtwayland5", "qt6-wayland", "xwayland", "xauth", "libxcb-cursor0"))
            (root / "var/lib/dpkg/status").write_text(status)
            def dpkg(*arguments, success=True):
                result = subprocess.run(["dpkg", "--root=" + str(root), *map(str, arguments)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                self.assertEqual(result.returncode == 0, success, result.stdout)
                return result
            def package(version, payload=None):
                return build_package(ROOT / "packages/amogos-update", packages, version=version, payload=payload)
            stamp = root / "var/lib/amogos-update/applied-version"
            counter = root / "var/lib/amogos-update/test-applied"
            initial = package("2.0.0-1", "#!/bin/sh\nexit 0\n")
            dpkg("--install", initial)
            self.assertEqual(stamp.read_text(), "2.0.0-1\n")
            result = subprocess.run(["chroot", str(root), "/usr/bin/amogos-update"], text=True, capture_output=True, check=True)
            self.assertEqual(result.stdout, "")
            self.assertFalse(counter.exists())
            payload = '#!/bin/sh\nset -eu\nprintf "%s>%s\\n" "$AMOGOS_UPDATE_FROM" "$AMOGOS_UPDATE_TO" >> /var/lib/amogos-update/test-applied\n'
            upgraded = package("2.0.1-1", payload)
            dpkg("--install", upgraded)
            self.assertEqual(stamp.read_text(), "2.0.1-1\n")
            self.assertEqual(counter.read_text(), "2.0.0-1>2.0.1-1\n")
            dpkg("--install", upgraded)
            self.assertEqual(counter.read_text().count("\n"), 1, "Reinstall reran an applied migration")
            broken = package("2.0.2-1", "#!/bin/sh\nexit 17\n")
            dpkg("--install", broken, success=False)
            self.assertEqual(stamp.read_text(), "2.0.1-1\n", "A failed migration advanced its version")
            installed = root / "usr/bin/amogos-update"
            installed.write_text(payload)
            installed.chmod(0o755)
            dpkg("--configure", "-a")
            self.assertEqual(stamp.read_text(), "2.0.2-1\n")
            self.assertEqual(counter.read_text().splitlines()[-1], "2.0.1-1>2.0.2-1")
            dpkg("--install", initial)
            self.assertEqual(stamp.read_text(), "2.0.2-1\n", "A downgrade reset migration history")
            self.assertEqual(counter.read_text().count("\n"), 2)
            dpkg("--install", package("2.0.3-1", payload))
            self.assertEqual(counter.read_text().splitlines()[-1], "2.0.2-1>2.0.3-1")
            dpkg("--purge", "amogos-update")
            self.assertFalse(stamp.exists())
            self.assertFalse((root / "usr/bin/amogos-update").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
