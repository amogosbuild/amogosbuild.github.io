# Missing display recovery preserves valid sessions and refuses nonexistent display sockets.
import os
import pathlib
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_store import session_environment as session


class SessionEnvironment(unittest.TestCase):
    def test_missing_display_is_recovered_from_owned_desktop(self):
        with patch.dict(os.environ,{"DISPLAY":"","QT_PLUGIN_PATH":"/wrong/plugins"},clear=True),patch.object(session,"desktop_environments",return_value=iter([{"DISPLAY":":42","XAUTHORITY":"/run/user/1000/xauth"}])),patch.object(session,"display_available",side_effect=lambda env:env.get("DISPLAY")==":42"),patch.object(session,"wayland_available",return_value=False):
            result=session.environment()
        self.assertEqual(result["DISPLAY"],":42")
        self.assertEqual(result["XAUTHORITY"],"/run/user/1000/xauth")
        self.assertNotIn("QT_PLUGIN_PATH",result)

    def test_valid_inherited_display_is_not_replaced(self):
        with patch.dict(os.environ,{"DISPLAY":":7","WAYLAND_DISPLAY":"wayland-0"},clear=True),patch.object(session,"display_available",return_value=True),patch.object(session,"wayland_available",return_value=True),patch.object(session,"desktop_environments") as scan:
            result=session.environment()
        self.assertEqual(result["DISPLAY"],":7")
        scan.assert_not_called()

    def test_invalid_recovered_display_is_not_copied(self):
        with patch.dict(os.environ,{},clear=True),patch.object(session,"desktop_environments",return_value=iter([{"DISPLAY":":999"}])),patch.object(session,"display_available",return_value=False),patch.object(session,"wayland_available",return_value=False):
            result=session.environment()
        self.assertNotIn("DISPLAY",result)


if __name__=="__main__":
    unittest.main()
