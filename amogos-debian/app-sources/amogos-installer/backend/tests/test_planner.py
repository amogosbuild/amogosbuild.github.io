# Storage regression tests protect existing systems and enforce the destructive-plan boundaries.
import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from amogos_install.planner import BIOS_BYTES, ESP_BYTES, GIB, MIB, fingerprint, make_plan
from amogos_install.runtime import InstallError


def fixture():
    return dict(path="/dev/nvme0n1", size=512*GIB, serial="fixture", sectorSize=512, table="gpt", tableId="fixture-gpt", blockedReason="", partitions=[
        dict(path="/dev/nvme0n1p1", number=1, start=MIB, size=ESP_BYTES, fs="vfat", esp=True, bios=False, uuid="EFI-1234", partuuid="efi-guid", type="efi", os="Windows Boot Manager", mounts=[], blockedReason="", minimumSize=None),
        dict(path="/dev/nvme0n1p2", number=2, start=MIB+ESP_BYTES, size=300*GIB, fs="ntfs", esp=False, bios=False, uuid="NTFS", partuuid="windows-guid", type="data", os="Windows", mounts=[], blockedReason="", minimumSize=100*GIB),
    ], free=[dict(start=301*GIB, size=210*GIB)])


class PlannerTests(unittest.TestCase):
    def test_alongside_prefers_free_space_and_preserves_esp(self):
        disk=fixture()
        before=copy.deepcopy(disk)
        plan=make_plan(disk, dict(mode="smart",rootBytes=64*GIB), True)
        self.assertFalse(any(s["action"]=="shrink" for s in plan["steps"]))
        self.assertFalse(any(s["action"]=="label" for s in plan["steps"]))
        self.assertFalse(any(s["action"]=="format" and s["path"]=="/dev/nvme0n1p1" for s in plan["steps"]))
        self.assertEqual(plan["esp"],"/dev/nvme0n1p1")
        self.assertIn("Windows",plan["preserved"])
        self.assertEqual(disk,before)

    def test_explicit_ntfs_shrink_preserves_start_and_identifiers(self):
        disk=fixture()
        plan=make_plan(disk,dict(mode="smart",rootBytes=64*GIB,shrinkPartition="/dev/nvme0n1p2"),True)
        shrink=next(s for s in plan["steps"] if s["action"]=="shrink")
        root=next(s for s in plan["steps"] if s.get("role")=="root" and s["action"]=="create")
        self.assertEqual(shrink["start"],disk["partitions"][1]["start"])
        self.assertGreaterEqual(shrink["size"],100*GIB)
        self.assertGreaterEqual(root["start"],shrink["start"]+shrink["size"])
        self.assertEqual(plan["fingerprint"],fingerprint(disk))

    def test_dirty_ntfs_is_never_a_shrink_candidate(self):
        disk=fixture();disk["free"]=[]
        disk["partitions"][1]["blockedReason"]="hibernated";disk["partitions"][1]["minimumSize"]=None
        with self.assertRaises(InstallError):
            make_plan(disk,dict(mode="smart",rootBytes=64*GIB),True)

    def test_insufficient_space_and_foreign_paths_are_rejected(self):
        disk=fixture()
        for request in [dict(mode="smart",rootBytes=500*GIB),dict(mode="manual",manualRoot="/dev/sda1"),dict(mode="manual",manualRoot="/dev/nvme0n1p1")]:
            with self.assertRaises(InstallError):
                make_plan(disk,request,True)

    def test_erase_produces_both_firmware_partitions(self):
        disk=fixture()
        plan=make_plan(disk,dict(mode="erase",rootBytes=80*GIB),False)
        creates=[s for s in plan["steps"] if s["action"]=="create"]
        self.assertEqual({s["role"] for s in creates},{"bios","esp","root"})
        self.assertEqual(plan["preserved"],[])
        self.assertTrue(plan["newEsp"])
        self.assertTrue(any(s["action"]=="label" for s in plan["steps"]))
        for one,two in zip(creates,creates[1:]):
            self.assertLessEqual(one["start"]+one["size"],two["start"])
        self.assertLess(creates[-1]["start"]+creates[-1]["size"],disk["size"])

    def test_manual_only_formats_the_assigned_root(self):
        disk=fixture()
        plan=make_plan(disk,dict(mode="manual",manualRoot="/dev/nvme0n1p2",manualEsp="/dev/nvme0n1p1"),True)
        formats=[s["path"] for s in plan["steps"] if s["action"]=="format"]
        self.assertEqual(formats,["/dev/nvme0n1p2"])
        self.assertFalse(any(s["action"] in ("create","shrink","label") for s in plan["steps"]))
        self.assertNotIn("Windows",plan["preserved"])
        self.assertTrue(plan["warnings"])

    def test_manual_can_allocate_in_unallocated_space(self):
        disk=fixture()
        plan=make_plan(disk,dict(mode="manual",manualRoot="new",freeStart=301*GIB,rootBytes=32*GIB),True)
        self.assertTrue(plan["root"].endswith("p3"))
        self.assertFalse(plan["newEsp"])

    def test_currently_mounted_disk_cannot_be_modified(self):
        disk=fixture();disk["blockedReason"]="Mounted root filesystem"
        with self.assertRaises(InstallError):
            make_plan(disk,dict(mode="erase"),True)

    def test_mbr_extended_layout_cannot_be_changed_implicitly(self):
        disk=fixture();disk["table"]="dos";disk["partitions"][1]["number"]=5
        disk["partitions"][0]["esp"]=False
        with self.assertRaises(InstallError):
            make_plan(disk,dict(mode="smart",rootBytes=32*GIB),False)

    def test_changed_layout_changes_fingerprint(self):
        disk=fixture();before=fingerprint(disk)
        disk["partitions"][1]["size"]-=MIB
        self.assertNotEqual(before,fingerprint(disk))

    def test_alignment_on_four_k_sector_drives(self):
        disk=fixture();disk["sectorSize"]=4096
        plan=make_plan(disk,dict(mode="smart",rootBytes=32*GIB+13),True)
        for step in plan["steps"]:
            if step["action"]=="create":
                self.assertEqual(step["start"]%MIB,0)
                self.assertEqual(step["size"]%MIB,0)

    def test_manual_encrypted_root_is_rejected(self):
        disk=fixture();disk["partitions"][1]["fs"]="BitLocker"
        with self.assertRaises(InstallError):
            make_plan(disk,dict(mode="manual",manualRoot="/dev/nvme0n1p2"),True)


if __name__ == "__main__":
    unittest.main()
