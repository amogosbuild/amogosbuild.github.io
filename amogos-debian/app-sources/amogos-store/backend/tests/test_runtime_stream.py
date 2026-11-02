# A real subprocess checks that APT's close-on-exec progress descriptor cannot close package-script stdout.
import io
import pathlib
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_store.runtime import stream


class RuntimeStreamTests(unittest.TestCase):
    def test_package_script_stdout_survives_progress_descriptor_close(self):
        child="import os; os.write(1,b'package stdout works\\n')"
        parent="import fcntl,os,subprocess,sys; fd=int(sys.argv[1]); assert fd>2; fcntl.fcntl(fd,fcntl.F_SETFD,fcntl.FD_CLOEXEC); sys.exit(subprocess.run([sys.executable,'-c',sys.argv[2]],close_fds=False).returncode)"
        with patch('sys.stdout',new_callable=io.StringIO) as output:
            stream([sys.executable,'-c',parent,'{status_fd}',child])
        self.assertIn('package stdout works',output.getvalue())


if __name__=='__main__':
    unittest.main()
