# Catalog regressions cover complete indexes, deep pages, descriptions, architectures, and repository versions.
import pathlib
import sys
import unittest
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_store import apt_catalog, catalog


def origin(site):
    return SimpleNamespace(site=site,archive="trixie",component="main",origin=site,trusted=True)


def version(number="1",site="deb.example.org",description="A package",architecture="amd64"):
    return SimpleNamespace(version=number,origins=[origin(site)],section="utils",summary="A tool",description=description,architecture=architecture,size=10,installed_size=20,homepage="")


def package(name,versions=None):
    versions=versions or [version()]
    return SimpleNamespace(name=name,candidate=versions[0],versions=versions,installed=None,is_upgradable=False)


class Cache(dict):
    def __iter__(self):
        return iter(self.values())


class AptBrowse(unittest.TestCase):
    def test_unfiltered_browse_pages_include_every_non_featured_package(self):
        cache=Cache({p.name:p for p in [package("tool-"+str(i).zfill(2)) for i in range(55)]})
        with patch.object(apt_catalog,"cache",return_value=cache),patch.object(apt_catalog,"component_metadata",return_value={}):
            with patch.object(apt_catalog,"normalize",wraps=apt_catalog.normalize) as normalize:
                first,total,_=apt_catalog.catalog()
                self.assertEqual(total,55)
                self.assertEqual(len(first),24)
                self.assertEqual(normalize.call_count,24)
            rows=first+apt_catalog.catalog(page=1)[0]+apt_catalog.catalog(page=2)[0]
        self.assertEqual({r["id"] for r in rows},set(cache.keys()))
        self.assertEqual(len(rows),55)

    def test_repo_browse_and_repo_listing_include_non_candidate_origins(self):
        newest=version("2","new.example.org")
        older=version("1","other.example.org")
        p=package("unfeatured-package",[newest,older])
        cache=Cache({p.name:p})
        repo=apt_catalog.origin_key(older.origins[0])
        with patch.object(apt_catalog,"cache",return_value=cache),patch.object(apt_catalog,"component_metadata",return_value={}):
            rows,total,_=apt_catalog.catalog(repo=repo)
        self.assertEqual(total,1)
        self.assertEqual((rows[0]["id"],rows[0]["repo"],rows[0]["version"]),(p.name,repo,"1"))
        self.assertIn(repo,[r["id"] for r in apt_catalog.repositories(cache)])

    def test_search_uses_descriptions_and_prefers_exact_names(self):
        values=[package("library",[version(description="Provides obscure-support-token")]),package("obscure-support-token")]
        cache=Cache({p.name:p for p in values})
        with patch.object(apt_catalog,"cache",return_value=cache),patch.object(apt_catalog,"component_metadata",return_value={}):
            rows,total,_=apt_catalog.catalog("obscure-support-token")
        self.assertEqual(total,2)
        self.assertEqual([r["id"] for r in rows],["obscure-support-token","library"])

    def test_enabled_foreign_architecture_is_not_hidden(self):
        p=package("library:i386",[version(architecture="i386")])
        with patch.object(apt_catalog,"cache",return_value=Cache({p.name:p})),patch.object(apt_catalog,"component_metadata",return_value={}):
            rows,total,_=apt_catalog.catalog()
            choices=apt_catalog.alternatives(p.name)
        self.assertEqual(total,1)
        self.assertEqual(rows[0]["id"],"library:i386")
        self.assertEqual(choices[0]["id"],"library:i386")

    def test_deep_pages_are_not_limited_to_first_24024_packages(self):
        with patch.object(apt_catalog,"catalog",return_value=([],70000,False)) as search:
            result=catalog.search(dict(source="deb",page=2000))
        self.assertEqual(result["totals"]["deb"],70000)
        self.assertEqual(search.call_args.args[-1],2000)


if __name__=="__main__":
    unittest.main()
