# Verify persistent credits, shallow root repair and rejection of broken live-image metadata.
import contextlib
import importlib.util
import io
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from archive import build_package


def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    value=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


ownership=module('ownership',ROOT/'packages/amogos-system/rootfs/usr/lib/amogos-system/root_ownership.py')
verify=module('verify',ROOT/'iso-tools/verify-root.py')


@unittest.skipUnless(os.geteuid()==0,'Use sudo for real filesystem ownership regression tests')
class SystemTests(unittest.TestCase):
    def test_tmpfiles_fails_on_bad_root_then_succeeds_without_changing_user_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=pathlib.Path(temporary)
            (root/'tmp').mkdir(mode=0o1777)
            (root/'tmp').chmod(0o1777)
            child=root/'user-file'
            child.write_text('preserve')
            os.chown(child,1000,1000)
            child.chmod(0o640)
            rule=root/'fixture.conf'
            rule.write_text('d /tmp/.X11-unix 1777 0 0 -\n')
            os.chown(root,1000,1000)
            root.chmod(0o775)
            command=['systemd-tmpfiles','--root='+str(root),'--create',str(rule)]
            failed=subprocess.run(command,capture_output=True,text=True)
            self.assertNotEqual(failed.returncode,0,failed.stdout+failed.stderr)
            self.assertTrue(ownership.repair(root))
            succeeded=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(succeeded.returncode,0,succeeded.stdout+succeeded.stderr)
            info=(root/'tmp/.X11-unix').stat()
            self.assertEqual((info.st_uid,info.st_gid,info.st_mode&0o7777),(0,0,0o1777))
            info=child.stat()
            self.assertEqual((info.st_uid,info.st_gid,info.st_mode&0o7777),(1000,1000,0o640))
            self.assertFalse(ownership.repair(root))
            link=root/'link'
            link.symlink_to(root,target_is_directory=True)
            with self.assertRaises(OSError):
                ownership.repair(link)

    def test_live_and_installed_roots_are_repaired_and_reboot_marker_is_preserved(self):
        for live in (False,True):
            with self.subTest(live=live),tempfile.TemporaryDirectory() as temporary:
                root=pathlib.Path(temporary)
                (root/'etc').mkdir()
                (root/'etc/os-release').write_text('ID=amogos\nVERSION_ID=2.1\n')
                (root/'run').mkdir()
                if live:
                    (root/'run/live/medium').mkdir(parents=True)
                (root/'run/reboot-required').write_text('Existing reboot reason\n')
                (root/'run/reboot-required.pkgs').write_text('other-package\n')
                root.chmod(0o775)
                os.chown(root,1000,1000)
                mapped=types.SimpleNamespace(Path=lambda value:root/str(value).lstrip('/'))
                with patch.object(ownership,'pathlib',mapped),patch.object(sys,'argv',['root-ownership','--mark-reboot']),contextlib.redirect_stdout(io.StringIO()) as output:
                    ownership.main()
                    ownership.main()
                self.assertEqual([json.loads(line)['changed'] for line in output.getvalue().splitlines()],[True,False])
                self.assertEqual((root/'run/reboot-required').read_text(),'Existing reboot reason\n')
                self.assertEqual((root/'run/reboot-required.pkgs').read_text(),'other-package\namogos-system\n')

    def test_package_contains_executable_credits_and_early_boot_guard(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=pathlib.Path(temporary)
            package=build_package(ROOT/'packages/amogos-system',root/'packages')
            extracted=root/'extracted'
            subprocess.run(['dpkg-deb','-x',str(package),str(extracted)],check=True)
            credits=extracted/'usr/bin/amogos-credits'
            self.assertEqual(credits.stat().st_mode&0o7777,0o755)
            self.assertEqual(subprocess.check_output([str(credits)],text=True),'AmogOS 2.1 Pro (Debian edition) developed by CursedMC64 and techtimefor.\n')
            self.assertEqual((extracted/'usr/libexec/amogos-root-ownership').stat().st_mode&0o7777,0o755)
            service=(extracted/'usr/lib/systemd/system/amogos-root-ownership.service').read_text()
            self.assertIn('Before=systemd-tmpfiles-setup.service sysinit.target',service)
            self.assertIn('WantedBy=sysinit.target',service)
            self.assertNotIn('ConditionPathExists',service)

    @unittest.skipUnless(shutil.which('mksquashfs'),'SquashFS tools are required')
    def test_builder_rejects_bad_directory_and_staged_image(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=pathlib.Path(temporary)
            source=root/'source'
            source.mkdir()
            (source/'file').write_text('fixture')
            for valid in (False,True):
                source.chmod(0o755 if valid else 0o775)
                os.chown(source,0 if valid else 1000,0 if valid else 1000)
                image=root/('good.squashfs' if valid else 'bad.squashfs')
                subprocess.run(['mksquashfs',str(source),str(image),'-noappend','-processors','1','-no-progress'],check=True,stdout=subprocess.DEVNULL)
                if valid:
                    verify.directory(source)
                    verify.squashfs(image)
                else:
                    with self.assertRaises(ValueError):
                        verify.directory(source)
                    with self.assertRaises(ValueError):
                        verify.squashfs(image)


if __name__=='__main__':
    unittest.main(verbosity=2)
