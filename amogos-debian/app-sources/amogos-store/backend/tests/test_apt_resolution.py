# Repository preferences must be scoped to the selected source family and exact version.
import pathlib
import sys
import unittest
from types import SimpleNamespace as S
from unittest.mock import Mock

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_store.apt_resolution import prefer_family


class Cache(list):
    pass


class FamilyResolution(unittest.TestCase):
    def test_unrelated_security_dependencies_keep_their_default_policy(self):
        origin=S(site="deb.debian.org",archive="stable",component="main")
        def v(source,number):return S(source_name=source,source_version=number,version=number,origins=[origin])
        wanted=v("gimp","3")
        cache=Cache([S(name="gimp",versions=[wanted]),S(name="libgimp",versions=[v("gimp","3"),v("gimp","2")]),S(name="libgegl",versions=[v("gegl","1")])])
        cache._depcache=Mock()
        prefer_family(cache,wanted,"deb.debian.org|stable|main")
        calls=cache._depcache.policy.create_pin.call_args_list
        self.assertEqual([call.args for call in calls],[("Version","gimp","3",990),("Version","libgimp","3",990)])


if __name__=="__main__":
    unittest.main()
