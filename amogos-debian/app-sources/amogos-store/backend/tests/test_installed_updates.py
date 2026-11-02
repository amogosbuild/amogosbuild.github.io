# Installed inventory and selected updates preserve source isolation, references and reviewed changes.
import contextlib
import io
import pathlib
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_store import apt_catalog,apt_transactions,flatpak_local,flatpak_transactions,inventory,updates,user_plans
from amogos_store.runtime import StoreError
from test_apt_browse import Cache,package,version


class InstalledUpdates(unittest.TestCase):
    def test_installed_inventory_includes_local_packages_and_paginates_all_sources(self):
        rows=[dict(id=str(i),name="Package "+str(i).zfill(2),source="deb",installed=True) for i in range(30)]
        with patch.object(inventory,"apt_items",return_value=rows),patch.object(inventory,"images",return_value=[dict(id="123",name="VLC",source="appimage",installed=True)]),patch.object(flatpak_local,"listing",side_effect=lambda scope:[dict(id="org.test.App",name="Flatpak "+scope,scope=scope,reference="app/org.test.App/x86_64/stable",source="flatpak",installed=True)]):
            first=inventory.search({})
            last=inventory.search(dict(page=1))
            self.assertEqual(first["total"],33)
            self.assertTrue(first["hasMore"])
            self.assertFalse(last["hasMore"])
            self.assertEqual(len(first["items"]+last["items"]),33)
            self.assertEqual(inventory.search(dict(source="flatpak"))["total"],2)
            self.assertEqual(inventory.search(dict(query="VLC"))["total"],1)
        p=package("local-app");p.installed=p.candidate;p.candidate=None
        with patch.object(apt_catalog,"cache",return_value=Cache({p.name:p})),patch.object(apt_catalog,"component_metadata",return_value={}):
            self.assertEqual(inventory.apt_items()[0]["version"],"1")

    def test_failed_inventory_source_does_not_hide_other_installed_software(self):
        with patch.object(inventory,"apt_items",side_effect=StoreError("APT failed")),patch.object(inventory,"images",return_value=[dict(id="1",name="Image",source="appimage")]),patch.object(flatpak_local,"listing",return_value=[]):
            value=inventory.search({})
        self.assertEqual(value["items"][0]["source"],"appimage")
        self.assertEqual(value["warnings"][0]["source"],"deb")

    def test_flatpak_partial_refs_are_expanded_and_runtime_branches_remain_distinct(self):
        def run(args,**kwargs):
            runtime="--runtime" in args
            return SimpleNamespace(stdout=("org.test.Platform\tPlatform\t1\tstable\tflathub\torg.test.Platform/x86_64/stable\n" if runtime else "org.test.App\tApp\t2\tstable\tflathub\torg.test.App/x86_64/stable\n"))
        with patch("shutil.which",return_value="/usr/bin/flatpak"),patch.object(flatpak_local,"run",side_effect=run):
            rows=flatpak_local.listing("user")
        self.assertEqual([v["reference"] for v in rows],["app/org.test.App/x86_64/stable","runtime/org.test.Platform/x86_64/stable"])
        self.assertTrue(rows[1]["runtime"])
        self.assertTrue(all(v["scope"]=="user" for v in rows))

    def test_flatpak_updates_retain_scope_and_reference(self):
        row=dict(id="org.test.App",name="App",version="1",reference="app/org.test.App/x86_64/stable",scope="user")
        with patch("shutil.which",return_value="flatpak"),patch.object(flatpak_local,"listing",side_effect=lambda scope:[row] if scope=="user" else []),patch.object(flatpak_local,"run",return_value=SimpleNamespace(stdout="org.test.App\tApp\t2\torg.test.App/x86_64/stable\n")):
            values=flatpak_local.updates()
        self.assertEqual(len(values),1)
        self.assertEqual((values[0]["scope"],values[0]["fromVersion"],values[0]["version"]),("user","1","2"))

    def test_selected_apt_plan_only_marks_requested_packages_and_preserves_automatic(self):
        chosen=package("chosen");chosen.installed=version("1");chosen.candidate=version("2");chosen.essential=False;chosen.marked_delete=False;chosen.is_auto_installed=True
        touched=[]
        chosen.mark_install=lambda **kwargs:touched.append(kwargs)
        unrelated=package("unrelated");unrelated.installed=unrelated.candidate
        c=Cache({p.name:p for p in [chosen,unrelated]});c.broken_count=0;c.required_download=10;c.required_space=20;c.get_changes=lambda:[chosen]
        import apt_pkg
        apt_pkg.init_system()
        with patch.object(apt_catalog,"cache",return_value=c):
            value=apt_transactions.resolve(dict(operation="update-selected",packages=["chosen"]))
            with self.assertRaises(StoreError):apt_transactions.resolve(dict(operation="update-selected",packages=["missing"]))
        self.assertEqual(value["packages"],["chosen"])
        self.assertEqual([v["id"] for v in value["changes"]],["chosen"])
        self.assertFalse(touched[0]["from_user"])
        self.assertTrue(value["changes"][0]["automatic"])

    def test_update_source_failure_is_separate_from_other_formats(self):
        with patch.object(apt_transactions,"updates",side_effect=StoreError("APT offline")),patch.object(flatpak_transactions,"updates",return_value=[dict(id="org.test.App")]),patch.object(updates,"image_updates",return_value=([dict(id="123")],[])):
            value=updates.get()
        self.assertEqual(value["flatpak"][0]["id"],"org.test.App")
        self.assertEqual(value["appimage"][0]["id"],"123")
        self.assertEqual(value["warnings"][0]["source"],"deb")

    def test_appimage_update_retains_selected_build_and_avoids_downgrades(self):
        current={"123":dict(name="App",version="2.0",download=2)}
        builds=[dict(number=1,version="9.0",name="Other.AppImage",size=100),dict(number=2,version="3.0",name="App.AppImage",size=20)]
        with patch.object(updates.appimages,"reconcile",return_value=current),patch.object(updates.appimage_catalog,"raw_details",return_value={"id":"123","name":"App"}),patch.object(updates.appimage_catalog,"downloads",return_value=builds):
            values,warnings=updates.image_updates()
            self.assertEqual(values[0]["download"],2)
            self.assertEqual(values[0]["fromVersion"],"2.0")
            builds[1]["version"]="1.0"
            self.assertEqual(updates.image_updates()[0],[])
        self.assertEqual(warnings,[])

    def test_user_tokens_are_private_single_use_and_never_authorize_system_scope(self):
        with tempfile.TemporaryDirectory() as directory,patch.object(user_plans,"user_state",return_value=pathlib.Path(directory)):
            value=user_plans.save(dict(source="flatpak",scope="user"))
            path=pathlib.Path(directory)/"flatpak-plans"/(value["token"]+".json")
            self.assertEqual(path.stat().st_mode & 0o777,0o600)
            self.assertEqual(user_plans.consume(value["token"])["scope"],"user")
            with self.assertRaises(StoreError):user_plans.consume(value["token"])
            value=user_plans.save(dict(source="flatpak",scope="system"))
            with self.assertRaises(StoreError):user_plans.consume(value["token"])
        with patch("os.geteuid",return_value=0):
            with self.assertRaises(StoreError):flatpak_transactions.resolve(dict(scope="user",id="org.test.App"))

    def test_orphaned_flatpak_can_be_removed_without_contacting_its_old_remote(self):
        item=dict(id="org.test.App",reference="app/org.test.App/x86_64/stable",origin="removed-origin")
        with patch.object(flatpak_local,"listing",return_value=[item]),patch.object(flatpak_transactions,"remotes",return_value=[]),patch.object(flatpak_transactions,"run",return_value=SimpleNamespace(stdout="a"*64)):
            value=flatpak_transactions.resolve(dict(id="org.test.App",operation="remove"))
        self.assertEqual(value["operation"],"remove")
        self.assertEqual(value["origin"],"removed-origin")

    def test_batch_refuses_origin_change_after_review(self):
        old=dict(source="flatpak",scope="system",operation="update-selected",commits={"ref":"abc"},items=[dict(remoteUrl="https://old.example")])
        fresh=dict(old,items=[dict(remoteUrl="https://new.example")])
        with patch.object(flatpak_transactions,"transaction_lock",return_value=contextlib.nullcontext()),patch.object(flatpak_transactions,"consume_plan",return_value=old),patch.object(flatpak_transactions,"resolve",return_value=fresh),patch.object(flatpak_transactions,"stream") as stream:
            with self.assertRaises(StoreError):flatpak_transactions.apply(dict(token="test"))
            stream.assert_not_called()


if __name__=="__main__":
    unittest.main()
