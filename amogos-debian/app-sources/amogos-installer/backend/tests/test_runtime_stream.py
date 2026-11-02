# Real child processes verify that progress descriptors cannot close stdout and progress bursts remain bounded.
import fcntl
import io
import os
import pathlib
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_install.runtime import InstallError, Reporter, Runner


class RuntimeStreamTests(unittest.TestCase):
    def test_progress_descriptor_closes_in_child_but_stdout_stays_writable(self):
        child = "import os; os.write(1,b'child stdout remains writable\\n')"
        parent = "import fcntl,os,subprocess,sys; fd=int(sys.argv[1]); assert fd>2; os.write(fd,b'pmstatus:test:50:Configuring\\n'); fcntl.fcntl(fd,fcntl.F_SETFD,fcntl.FD_CLOEXEC); result=subprocess.run([sys.executable,'-c',sys.argv[2]],close_fds=False); sys.exit(result.returncode)"
        lines = []
        log = io.StringIO()
        Runner(log).stream([sys.executable, "-c", parent, "{status_fd}", child], lines.append)
        self.assertIn("pmstatus:test:50:Configuring\n", lines)
        self.assertIn("child stdout remains writable\n", lines)

    def test_large_stream_keeps_only_error_tail_and_reaps_child(self):
        command = [sys.executable, "-c", "import sys; print('x'*20000); print('LAST FAILURE'); sys.exit(7)"]
        with self.assertRaises(InstallError) as caught:
            Runner().stream(command)
        self.assertIn("LAST FAILURE", str(caught.exception))
        self.assertLess(len(str(caught.exception)), 2200)

    def test_progress_burst_is_throttled_but_terminal_events_are_immediate(self):
        reporter = Reporter()
        with patch("sys.stdout", new_callable=io.StringIO) as output, patch("amogos_install.runtime.time.monotonic", return_value=10):
            for i in range(10000):
                reporter.emit("copy", i / 10000, "Copying")
            reporter.emit("complete", 1, "Done", done=True)
            self.assertEqual(len(output.getvalue().splitlines()), 2)
            self.assertIn('"done": true', output.getvalue())


if __name__ == "__main__":
    unittest.main()
