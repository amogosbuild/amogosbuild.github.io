# VLC AppImage listings retain both other AppImage builds and verified APT/Flatpak choices.
import pathlib
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_store import alternatives


class Alternatives(unittest.TestCase):
    def test_vlc_appimage_name_resolves_all_available_source_choices(self):
        current=dict(id="2194959",name="Vlc appimage",source="appimage",repo="appimagehub",version="3.0.21")
        older=dict(id="1231861",name="VLC Media Player",source="appimage",repo="appimagehub",version="3.0.11")
        apt=dict(id="vlc",name="VLC",source="deb",repo="main",version="3.0.21")
        flat=dict(id="org.videolan.VLC",name="VLC",source="flatpak",repo="flathub",version="3.0.21")
        with patch.object(alternatives.catalog,"details",return_value=current),patch.object(alternatives.catalog,"local_images",return_value={}),patch.object(alternatives.apt_catalog,"alternatives",return_value=[apt]) as apt_choices,patch.object(alternatives.flatpak_catalog,"details",return_value=flat) as flat_choice,patch.object(alternatives.appimage_catalog,"catalog",return_value=([current,older],2,False)) as image_choices:
            result=alternatives.get(dict(id=current["id"],source="appimage"))
        self.assertEqual({v["source"] for v in result["items"]},{"deb","flatpak","appimage"})
        self.assertEqual(len([v for v in result["items"] if v["source"]=="appimage"]),2)
        apt_choices.assert_called_once_with("vlc")
        flat_choice.assert_called_once_with("org.videolan.VLC")
        self.assertEqual(image_choices.call_args.args[0],"vlc")


if __name__=="__main__":
    unittest.main()
