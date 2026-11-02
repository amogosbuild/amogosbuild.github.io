# Installed AppImages keep executable permissions, correct menu entries, migration, and useful launch diagnostics.
import contextlib
import io
import json
import os
import pathlib
import struct
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_store import appimage_categories,appimage_integration,appimage_launch,appimages
from amogos_store.runtime import StoreError


class Response(io.BytesIO):
    def __init__(self,data):
        super().__init__(data)
        self.headers={"Content-Length":str(len(data))}


@contextlib.contextmanager
def home():
    with tempfile.TemporaryDirectory() as directory,contextlib.ExitStack() as stack:
        folder=pathlib.Path(directory)
        state=folder/".local/share/amogos-store"
        state.mkdir(parents=True)
        stack.enter_context(patch.object(pathlib.Path,"home",return_value=folder))
        stack.enter_context(patch.object(appimages,"user_state",return_value=state))
        stack.enter_context(patch.object(appimage_launch,"user_state",return_value=state))
        stack.enter_context(patch.object(appimage_integration,"refresh_menus"))
        yield folder,state


def header():
    data=bytearray(64)
    data[:6]=b"\x7fELF\x02\x01"
    data[8:11]=b"AI\x02"
    struct.pack_into("<H",data,18,62)
    return bytes(data)


class AppImageIntegration(unittest.TestCase):
    def test_known_hub_categories_use_registered_menu_categories(self):
        for identity,category in [(482,"AudioVideo"),(393,"AudioVideo"),(239,"Graphics"),(202,"Game"),(243,"Development"),(222,"Office"),(248,"Network"),(245,"System")]:
            self.assertIn(category,appimage_categories.categories_for(dict(typeid=identity)))
        self.assertEqual(appimage_categories.categories_for(dict(typename="Video Players")),["AudioVideo","Video"])

    def test_install_sets_executable_bits_and_video_menu_category(self):
        raw=dict(id=123,name="Video player",typeid=482,xdg_type="bin")
        choice=dict(number=1,name="Video.AppImage",version="1",url="https://example.com/video",md5="")
        with home() as (folder,state),patch.object(appimages.appimage_catalog,"raw_details",return_value=raw),patch.object(appimages.appimage_catalog,"downloads",return_value=[choice]),patch.object(appimages,"open_url",return_value=Response(header())),contextlib.redirect_stdout(io.StringIO()):
            appimages.install(dict(id="123",download=1))
            entry=appimages.manifest()["123"]
            binary=pathlib.Path(entry["path"])
            desktop=pathlib.Path(entry["desktop"])
            self.assertEqual(binary.stat().st_mode & 0o777,0o755)
            self.assertEqual(desktop.stat().st_mode & 0o777,0o755)
            self.assertIn("Categories=AudioVideo;Video;",desktop.read_text())
            self.assertIn("Exec=/usr/libexec/amogos-appimage-open 123",desktop.read_text())

    def test_existing_install_is_repaired_offline_from_cached_category(self):
        with home() as (folder,state):
            path=state/"appimages/123/application.AppImage"
            path.parent.mkdir(parents=True)
            path.write_bytes(header())
            path.chmod(0o600)
            appimages.save({"123":dict(path=str(path),name="Player",version="1")})
            with patch.object(appimage_integration,"cached_categories",return_value=["AudioVideo","Video"]):
                rows=appimages.reconcile()
            self.assertEqual(path.stat().st_mode & 0o777,0o755)
            self.assertEqual(rows["123"]["integrationVersion"],2)
            self.assertIn("Categories=AudioVideo;Video;",pathlib.Path(rows["123"]["desktop"]).read_text())

    def test_launch_repairs_mode_and_clears_host_qt_plugin_paths(self):
        with home() as (folder,state):
            path=state/"app.AppImage"
            path.write_bytes(header())
            path.chmod(0o600)
            process=SimpleNamespace(pid=10,wait=Mock(side_effect=subprocess.TimeoutExpired("app",2.5)))
            with patch.dict(os.environ,{"QT_PLUGIN_PATH":"/host/qt6/plugins"}),patch.object(appimage_launch.subprocess,"Popen",return_value=process) as start:
                result=appimage_launch.start("123",path)
            self.assertTrue(result["launched"])
            self.assertEqual(path.stat().st_mode & 0o777,0o755)
            self.assertNotIn("QT_PLUGIN_PATH",start.call_args.kwargs["env"])

    def test_failed_launch_returns_the_actual_error(self):
        with home() as (folder,state):
            path=state/"app.AppImage"
            path.write_bytes(header())
            def start(*args,**kwargs):
                kwargs["stdout"].write(b"error while loading shared libraries: libexample.so: cannot open shared object file\n")
                return SimpleNamespace(pid=10,wait=Mock(return_value=127))
            with patch.object(appimage_launch.subprocess,"Popen",side_effect=start),patch("amogos_store.appimage_extract.prepare",return_value=([str(path)],{})):
                with self.assertRaisesRegex(StoreError,"publisher's AppImage is missing the required library libexample.so"):
                    appimage_launch.start("123",path)

    def test_fuse_failure_retries_the_runtime_extraction_mode(self):
        with home() as (folder,state):
            path=state/"app.AppImage"
            path.write_bytes(header())
            def start(*args,**kwargs):
                if kwargs["env"].get("APPDIR"):
                    return SimpleNamespace(pid=11,wait=Mock(side_effect=subprocess.TimeoutExpired("app",2.5)))
                kwargs["stdout"].write(b"fuse: device not found\n")
                return SimpleNamespace(pid=10,wait=Mock(return_value=1))
            with patch.object(appimage_launch.subprocess,"Popen",side_effect=start) as launch,patch("amogos_store.appimage_extract.prepare",return_value=([str(path)],{"APPDIR":str(state/"extracted")})):
                self.assertTrue(appimage_launch.start("123",path)["launched"])
            self.assertEqual(launch.call_count,2)


if __name__=="__main__":
    unittest.main()
