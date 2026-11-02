# Interrupted package configuration is reviewed explicitly and never silently ignored during a normal install.
import pathlib
import sys
import unittest
from types import SimpleNamespace as S
from unittest.mock import patch

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_store import apt_catalog,apt_state,apt_transactions
from amogos_store.runtime import StoreError
from test_apt_browse import Cache,package


class InterruptedConfiguration(unittest.TestCase):
    def test_pending_dpkg_states_are_not_confused_with_removed_conffiles(self):
        rows="mime\t1\thalf-configured\nfoo\t2\tunpacked\nold\t1\tconfig-files\nready\t1\tinstalled\ntriggers\t1\ttriggers-pending\n"
        with patch.object(apt_state,"run",return_value=S(stdout=rows)):
            self.assertEqual([v["id"] for v in apt_state.pending()],["foo","mime","triggers"])

    def test_normal_install_points_to_repair_instead_of_starting_dpkg(self):
        c=Cache();c.broken_count=0
        with patch.object(apt_catalog,"cache",return_value=c),patch.object(apt_state,"pending",return_value=[dict(id="mime",version="1",state="half-configured")]):
            with self.assertRaisesRegex(StoreError,"Repair interrupted installation"):
                apt_transactions.resolve(dict(operation="install",id="vlc"))

    def test_system_repair_reviews_pending_configuration_without_inventing_installs(self):
        p=package("mime");p.installed=p.candidate
        c=Cache({p.name:p});c.broken_count=0;c.required_download=0;c.required_space=0;c.get_changes=lambda:[]
        pending=[dict(id="mime",version="1",state="half-configured")]
        with patch.object(apt_catalog,"cache",return_value=c),patch.object(apt_state,"pending",return_value=pending):
            plan=apt_transactions.resolve(dict(operation="repair-system"))
        self.assertEqual(plan["changes"][0]["action"],"configure")
        self.assertEqual(plan["pendingConfiguration"],pending)
        self.assertEqual(plan["downloadBytes"],0)


if __name__=="__main__":
    unittest.main()
