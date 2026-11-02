# Durable job boundaries reject foreign reviews, unsafe paths, session-scoped units, and false completion.
import contextlib
import io
import json
import pathlib
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from amogos_store import jobs,runtime


class DurableJobs(unittest.TestCase):
    def test_legacy_root_group_writable_parent_is_migrated_but_world_write_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            path=pathlib.Path(temporary)
            path.chmod(0o775)
            jobs.directory(path,0o755,repair_legacy=True)
            self.assertEqual(path.stat().st_mode & 0o777,0o755)
            path.chmod(0o777)
            with self.assertRaises(runtime.StoreError):
                jobs.directory(path,0o755,repair_legacy=True)

    def test_service_runs_as_a_system_unit_with_soft_memory_control(self):
        with patch.object(runtime,"run") as run:
            jobs.launch_unit("a"*48)
        command=run.call_args.args[0]
        self.assertEqual(command[0],"systemd-run")
        self.assertNotIn("--user",command)
        self.assertIn("--property=MemoryHigh=256M",command)
        self.assertFalse(any("MemoryMax=" in item for item in command))
        self.assertEqual(command[-1],"a"*48)

    def test_bad_id_and_user_flatpak_cannot_create_root_jobs(self):
        for value in ("../etc/passwd","--help","a"*47,"z"*48):
            with self.assertRaises(runtime.StoreError):jobs.identity(value)
        with self.assertRaises(runtime.StoreError):jobs.start("flatpak-apply",dict(scope="user"))

    def test_review_is_checked_before_creating_a_job(self):
        with patch.object(runtime,"read_plan",side_effect=runtime.StoreError("Review expired")),patch.object(jobs,"directory") as directory:
            with self.assertRaisesRegex(runtime.StoreError,"Review expired"):
                jobs.start("apt-apply",dict(token="a"*48))
        directory.assert_not_called()

    def test_finished_job_is_retained_and_receipt_does_not_expose_token(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=pathlib.Path(temporary)
            previous=dict(source="deb",operation="install",id="hello",summary="Install hello")
            def launched(key):
                folder=jobs.ROOT/key
                private=jobs.load(folder/"request.json")
                self.assertEqual(private["request"]["token"],"secret-review")
                state=jobs.load(folder/"state.json")
                state.update(status="completed",message="Finished",progress=1,done=True)
                jobs.write_state(folder,state)
            with patch.object(jobs,"ROOT",root/"jobs"),patch.object(jobs,"OWNERS",root/"owners"),patch.object(runtime,"owner",return_value=0),patch.object(runtime,"read_plan",return_value=previous),patch.object(jobs,"launch_unit",side_effect=launched),contextlib.redirect_stdout(io.StringIO()) as output:
                jobs.start("apt-apply",dict(token="secret-review"))
                rows=jobs.listing()["items"]
            self.assertEqual(rows[0]["status"],"completed")
            self.assertNotIn("secret-review",json.dumps(rows))
            self.assertTrue(json.loads(output.getvalue().splitlines()[-1])["done"])

    def test_dead_unit_is_reported_as_interrupted(self):
        with patch.object(jobs,"load",return_value=dict(status="running",updatedAt=time.time()-20)),patch.object(runtime,"run") as run:
            run.return_value.returncode=0
            run.return_value.stdout="inactive\n"
            state=jobs.state_for("a"*48)
        self.assertEqual(state["status"],"failed")
        self.assertIn("Repair interrupted installation",state["message"])


if __name__=="__main__":
    unittest.main()
