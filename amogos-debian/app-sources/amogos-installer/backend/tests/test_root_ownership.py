# Exercise real SquashFS extraction and minimum persistent-core selection without touching any disks.
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
if sys.platform=='linux':
    from amogos_install import installer
    from amogos_install.runtime import Runner


@unittest.skipUnless(sys.platform=='linux','The installer runs on Linux')
class RootOwnershipTests(unittest.TestCase):
    @unittest.skipUnless(hasattr(os,'geteuid') and os.geteuid()==0 and shutil.which('mksquashfs'),'Real extraction requires root and squashfs-tools')
    def test_copy_repairs_legacy_image_root_and_preserves_user_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=pathlib.Path(temporary)
            source=folder/'source'
            source.mkdir()
            child=source/'user-owned'
            child.write_text('keep my ownership')
            os.chown(child,1000,1000)
            child.chmod(0o640)
            os.chown(source,1000,1000)
            source.chmod(0o775)
            medium=folder/'medium'
            (medium/'live').mkdir(parents=True)
            subprocess.run(['mksquashfs',str(source),str(medium/'live/filesystem.squashfs'),'-noappend','-processors','1','-no-progress'],check=True,stdout=subprocess.DEVNULL)
            instance=installer.Installer({}, {},Mock())
            instance.runner=Runner()
            instance.target=folder/'target'
            instance.target.mkdir()
            instance._copy(medium)
            info=instance.target.stat()
            self.assertEqual((info.st_uid,info.st_gid,info.st_mode&0o7777),(0,0,0o755))
            info=(instance.target/'user-owned').stat()
            self.assertEqual((info.st_uid,info.st_gid,info.st_mode&0o7777),(1000,1000,0o640))

    def test_core_upgrades_old_version_and_preserves_current_or_future(self):
        for version,upgrade in [('2.1.0-1',True),('2.1.0-2',False),('2.2.0-1',False)]:
            with self.subTest(version=version),tempfile.TemporaryDirectory() as temporary:
                folder=pathlib.Path(temporary)
                package=folder/'core.deb'
                package.write_bytes(b'fixture')
                (folder/'var/tmp').mkdir(parents=True)
                instance=installer.Installer({}, {},Mock())
                instance.target=folder
                def command(args,**kwargs):
                    if args[0]=='dpkg-query':
                        return subprocess.CompletedProcess(args,0,stdout='installed '+version)
                    if args[0:2]==['dpkg','--compare-versions']:
                        return subprocess.run(args)
                    self.assertEqual(args,['dpkg','-i','/var/tmp/amogos-system.deb'])
                    self.assertEqual((folder/'var/tmp/amogos-system.deb').read_bytes(),b'fixture')
                    return subprocess.CompletedProcess(args,0)
                instance.chroot=Mock(side_effect=command)
                with patch.object(installer,'SYSTEM_PACKAGE',package):
                    instance._ensure_system_core()
                self.assertEqual(any(call.args[0][:2]==['dpkg','-i'] for call in instance.chroot.call_args_list),upgrade)
                self.assertFalse((folder/'var/tmp/amogos-system.deb').exists())


if __name__=='__main__':
    unittest.main()
