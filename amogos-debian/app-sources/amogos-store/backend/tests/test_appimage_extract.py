# Extraction fallback repairs library paths, reuses unchanged AppDirs, and refreshes replaced downloads.
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_store.appimage_extract import prepare
from amogos_store import appimage_catalog


class Extraction(unittest.TestCase):
    def test_extract_cache_and_replaced_image(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=pathlib.Path(temporary)
            path=root/"application.AppImage"
            path.write_text("#!/bin/sh\nmkdir -p squashfs-root/usr/lib\nprintf '#!/bin/sh\\nexit 0\\n' > squashfs-root/AppRun\nchmod +x squashfs-root/AppRun\n")
            path.chmod(0o755)
            command,env=prepare(path,{},root/"launch.log")
            self.assertTrue(pathlib.Path(command[0]).is_file())
            self.assertIn(str(root/"extracted/usr/lib"),env["LD_LIBRARY_PATH"])
            marker=root/"extracted/.amogos-extracted"
            previous=marker.stat().st_mtime_ns
            prepare(path,{},root/"launch.log")
            self.assertEqual(marker.stat().st_mtime_ns,previous)
            path.write_text(path.read_text()+"\n")
            prepare(path,{},root/"launch.log")
            self.assertNotEqual(marker.stat().st_mtime_ns,previous)

    def test_only_known_incomplete_artifact_is_excluded(self):
        raw=dict(downloadlink1="https://example.org/one",downloadname1="VLC.AppImage",downloadmd5sum1="42cc4eae43b37936145af364dab8f530",downloadlink2="https://example.org/two",downloadname2="VLC-fixed.AppImage",downloadmd5sum2="new-publisher-build")
        self.assertEqual([v["number"] for v in appimage_catalog.downloads(raw)],[2])


if __name__=="__main__":
    unittest.main()
