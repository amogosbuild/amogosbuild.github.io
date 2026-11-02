# Boundary tests protect review ownership, source identities, downloads, and privileged execution.
import contextlib
import io
import json
import pathlib
import struct
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_store import appimage_catalog,appimages,flatpak_transactions,network,runtime
from amogos_store.runtime import StoreError


class Boundaries(unittest.TestCase):
    def test_missing_flatpak_has_a_clear_install_requirement(self):
        with patch("shutil.which",return_value=None):
            with self.assertRaisesRegex(StoreError,"Flatpak needs to be installed"):
                flatpak_transactions.check_remote()

    def test_package_and_flatpak_argument_injection_is_rejected(self):
        for value in ["--help","vlc;reboot","x y","../../etc/passwd","$(id)",""]:
            with self.assertRaises(StoreError):runtime.package_name(value)
        for value in ["--help","org.foo.Bar/../../x","org.foo.Bar;reboot","x y"]:
            with self.assertRaises(StoreError):runtime.app_id(value)
        self.assertEqual(runtime.package_name("libgtk-3-0t64:amd64"),"libgtk-3-0t64:amd64")
        self.assertEqual(runtime.app_id("com.thebrokenrail.MCPIReborn"),"com.thebrokenrail.MCPIReborn")

    def test_private_addresses_and_insecure_redirect_targets_are_rejected(self):
        for address in ["127.0.0.1","10.1.2.3","169.254.169.254","::1","fc00::1"]:
            with patch("socket.getaddrinfo",return_value=[(2,1,6,"",(address,443))]):
                with self.assertRaises(StoreError):network.public_url("https://example.com/file")
        for url in ["http://example.com/file","file:///etc/passwd","https://user:pass@example.com/x","https://example.com:8443/x"]:
            with self.assertRaises(StoreError):network.public_url(url)

    def test_appimage_header_and_machine_type_are_checked(self):
        header=bytearray(64);header[:6]=b"\x7fELF\x02\x01";header[8:11]=b"AI\x02";struct.pack_into("<H",header,18,62)
        appimages.validate_header(header)
        for index,value in [(0,0),(8,0),(4,1),(18,183)]:
            bad=bytearray(header);bad[index]=value
            with self.assertRaises(StoreError):appimages.validate_header(bad)
        with self.assertRaises(StoreError):appimages.validate_header(b"<html>not an executable</html>")

    def test_download_choices_exclude_arm_and_non_appimage_files(self):
        item=dict(downloadname1="app-arm64.AppImage",downloadlink1="https://example.com/arm",download_package_arch1="aarch64",downloadname2="app-amd64.deb",downloadlink2="https://example.com/deb",download_package_type2="debian-package",downloadname3="app-x86_64.AppImage",downloadlink3="https://example.com/app",download_package_arch3="x86-64")
        self.assertEqual([x["number"] for x in appimage_catalog.downloads(item)],[3])

    def test_root_never_installs_or_launches_appimages(self):
        with patch("os.geteuid",return_value=0):
            with self.assertRaises(StoreError):appimages.install(dict(id="123",download=1))

    def test_appimage_manifest_cannot_remove_a_foreign_path(self):
        with tempfile.TemporaryDirectory() as folder,patch.object(appimages,"user_state",return_value=pathlib.Path(folder)),patch.object(appimages,"manifest",return_value={"123":dict(path="/etc/passwd")}):
            with self.assertRaises(StoreError):appimages.remove("123")

    def test_review_tokens_are_owner_bound_single_use_and_expire(self):
        with tempfile.TemporaryDirectory() as folder,patch.object(runtime,"PLAN_DIRECTORY",pathlib.Path(folder)),patch.object(runtime,"require_root"),patch.object(runtime,"owner",return_value=1001):
            p=runtime.save_plan(dict(source="deb",changes=[]))
            path=pathlib.Path(folder)/(p["token"]+".json")
            self.assertEqual(path.stat().st_mode & 0o777,0o600)
            with patch.object(runtime,"owner",return_value=1002):
                with self.assertRaises(StoreError):runtime.consume_plan(p["token"],"deb")
            self.assertTrue(path.is_file())
            runtime.consume_plan(p["token"],"deb")
            with self.assertRaises(StoreError):runtime.consume_plan(p["token"],"deb")
            p=runtime.save_plan(dict(source="deb",changes=[]))
            path=pathlib.Path(folder)/(p["token"]+".json")
            value=json.loads(path.read_text());value["expires"]=time.time()-1;path.write_text(json.dumps(value))
            with self.assertRaises(StoreError):runtime.consume_plan(p["token"],"deb")
            with self.assertRaises(StoreError):runtime.consume_plan("../../passwd","deb")

    def test_progress_is_real_and_silent_subprocesses_have_a_timeout(self):
        output=io.StringIO()
        with contextlib.redirect_stdout(output):
            runtime.stream([sys.executable,"-c","print('pmstatus:test:40:Installing')"])
        events=[json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(events[0]["progress"],.4)
        start=time.monotonic()
        with self.assertRaises(StoreError):
            runtime.stream([sys.executable,"-c","import time; time.sleep(10)"],timeout=.1)
        self.assertLess(time.monotonic()-start,3)


if __name__=="__main__":
    unittest.main()
