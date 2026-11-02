# Test the real migration against disposable identity files and real Debian version comparisons.
import contextlib
import importlib.util
import io
import pathlib
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

SOURCE=pathlib.Path(__file__).resolve().parents[1]/'packages/amogos-update/rootfs/usr/lib/amogos-update/migrate.py'
spec=importlib.util.spec_from_file_location('migration',SOURCE)
migration=importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class MigrationTests(unittest.TestCase):
    def exercise(self,version,symlink=True):
        with tempfile.TemporaryDirectory() as temporary:
            root=pathlib.Path(temporary)
            for name in ('etc','usr/lib','bin'):
                (root/name).mkdir(parents=True,exist_ok=True)
            canonical=root/'usr/lib/os-release'
            canonical.write_text('# AmogOS identity is retained across installation across...\nID=amogos\nVERSION_ID='+version+'\nOS_VERSION='+version+'\n')
            backup=root/'usr/lib/os-release.distrib'
            backup.write_text('ID=debian\nVERSION_ID=13\n')
            etc=root/'etc/os-release'
            if symlink:
                etc.symlink_to('../usr/lib/os-release')
            else:
                etc.write_bytes(canonical.read_bytes())
            before={str(p.relative_to(root)):(p.read_bytes(),p.stat().st_mtime_ns) for p in root.rglob('*') if p.is_file()}
            real_run=subprocess.run
            def command(args,**kwargs):
                if args[:2]==['dpkg','--compare-versions']:
                    return real_run(args,**kwargs)
                return subprocess.CompletedProcess(args,0)
            mapped=types.SimpleNamespace(Path=lambda value:root/str(value).lstrip('/'))
            with patch.object(migration,'pathlib',mapped),patch.object(migration.os,'geteuid',return_value=0),patch.object(migration,'repositories') as repositories,patch.object(migration.subprocess,'run',side_effect=command),patch.object(migration.subprocess,'check_output',return_value='LOCAL\n'),contextlib.redirect_stdout(io.StringIO()) as output:
                migration.main()
            after={str(p.relative_to(root)):(p.read_bytes(),p.stat().st_mtime_ns) for p in root.rglob('*') if p.is_file()}
            if version in ('2.1','2.1.1','2.2','3.0'):
                self.assertEqual(output.getvalue(),'You are already on the latest AmogOS version\n')
                self.assertEqual(before,after)
                repositories.assert_not_called()
            else:
                self.assertEqual(migration.fields(canonical)['OS_VERSION'],'2.1')
                self.assertEqual(migration.fields(etc)['VERSION_ID'],'2.1')
                self.assertFalse(any(line.startswith('#') for line in canonical.read_text().splitlines()))
                self.assertEqual((root/'etc/amogos-release').read_text(),'2.1\n')
                self.assertEqual(backup.read_text(),'ID=debian\nVERSION_ID=13\n')
                self.assertTrue(etc.is_symlink())
                repositories.assert_called_once()

    def test_older_versions_upgrade_regular_and_symlink_identity(self):
        self.exercise('2.0')
        self.exercise('2',False)

    def test_current_and_future_versions_change_nothing(self):
        for version in ('2.1','2.1.1','2.2','3.0'):
            with self.subTest(version=version):
                self.exercise(version)


if __name__=='__main__':
    unittest.main(verbosity=2)
